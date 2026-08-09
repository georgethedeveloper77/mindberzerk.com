package com.mindberzerk.device_probe

/**
 * CPU topology and live frequencies.
 *
 * Topology is resolved once and cached: cores do not change domain while the
 * process is alive, and re-walking sysfs on every 2 Hz tick would be several
 * dozen file opens per second for an answer that cannot have changed.
 */
internal class CpuProbe {

    private val coreCount: Int = resolveCoreCount()

    /** Cached topology. Fastest cluster first. */
    val clusters: List<ClusterSpec> by lazy { resolveClusters() }

    /** True when related_cpus was readable, so the grouping is fact not guess. */
    var clustersAreAuthoritative: Boolean = false
        private set

    internal data class ClusterSpec(
        val label: String,
        val coreIds: List<Int>,
        val minKhz: Long?,
        val maxKhz: Long?,
        val governor: String?,
    )

    fun coreCount(): Int = coreCount

    fun canReadFrequencies(): Boolean =
        (0 until coreCount).any { currentKhz(it) != null }

    fun canReadGovernor(): Boolean = clusters.any { it.governor != null }

    fun currentKhz(core: Int): Long? =
        SysFs.readLong("/sys/devices/system/cpu/cpu$core/cpufreq/scaling_cur_freq")
            ?: SysFs.readLong("/sys/devices/system/cpu/cpufreq/policy$core/scaling_cur_freq")

    /**
     * Core 0 has no `online` file on most kernels because it cannot be
     * offlined. Absent file therefore means online, not unknown.
     */
    fun isOnline(core: Int): Boolean? {
        if (core == 0) return true
        val raw = SysFs.readInt("/sys/devices/system/cpu/cpu$core/online") ?: return null
        return raw == 1
    }

    /**
     * Aggregate `cpu` line of /proc/stat as (idle+iowait, total).
     *
     * Expected to fail on Android 12+. Attempted anyway because the budget
     * devices this targets are frequently laxer than the flagships, and the
     * read costs one failed open when it is denied.
     */
    fun jiffies(): Pair<Long, Long>? {
        val line = SysFs.readLines("/proc/stat")
            ?.firstOrNull { it.startsWith("cpu ") }
            ?: return null
        val fields = line.split(Regex("\\s+")).drop(1).mapNotNull { it.toLongOrNull() }
        if (fields.size < 5) return null
        val idle = fields[3] + fields[4]
        return Pair(idle, fields.sum())
    }

    private fun resolveCoreCount(): Int {
        val fromSysFs = SysFs.numberedDirs("/sys/devices/system/cpu", "cpu").size
        // availableProcessors reports ONLINE cores only, so a device with two
        // clusters idled down reports 4 where sysfs reports 8. Take the larger.
        return maxOf(fromSysFs, Runtime.getRuntime().availableProcessors())
    }

    private fun resolveClusters(): List<ClusterSpec> {
        val byPolicy = clustersFromPolicies()
        if (byPolicy.isNotEmpty()) {
            clustersAreAuthoritative = true
            return label(byPolicy)
        }
        return label(clustersFromMaxFrequency())
    }

    /**
     * The canonical grouping: each `cpufreq/policyN` directory is one frequency
     * domain, and `related_cpus` names its members.
     */
    private fun clustersFromPolicies(): List<RawCluster> {
        val policies = SysFs.numberedDirs("/sys/devices/system/cpu/cpufreq", "policy")
        val out = mutableListOf<RawCluster>()
        for (policy in policies) {
            val base = "/sys/devices/system/cpu/cpufreq/policy$policy"
            val related = SysFs.readText("$base/related_cpus")
                ?: SysFs.readText("$base/affected_cpus")
                ?: continue
            val cores = SysFs.parseCpuList(related)
            if (cores.isEmpty()) continue
            out.add(
                RawCluster(
                    coreIds = cores,
                    minKhz = SysFs.readLong("$base/cpuinfo_min_freq"),
                    maxKhz = SysFs.readLong("$base/cpuinfo_max_freq"),
                    governor = SysFs.readText("$base/scaling_governor"),
                )
            )
        }
        return out
    }

    /**
     * Fallback: group cores by identical `cpuinfo_max_freq`.
     *
     * A good guess and not a fact, which is why [clustersAreAuthoritative] stays
     * false. Two clusters with the same ceiling but different efficiency cores
     * would be merged here, and the UI must not present that as certain.
     */
    private fun clustersFromMaxFrequency(): List<RawCluster> {
        val grouped = LinkedHashMap<Long, MutableList<Int>>()
        var sawAny = false
        for (core in 0 until coreCount) {
            val base = "/sys/devices/system/cpu/cpu$core/cpufreq"
            val max = SysFs.readLong("$base/cpuinfo_max_freq") ?: continue
            sawAny = true
            grouped.getOrPut(max) { mutableListOf() }.add(core)
        }
        if (!sawAny) {
            // Nothing readable at all. Report one cluster covering every core
            // rather than an empty list, so the UI still has a shape to draw
            // and the capability flag explains why it is empty of numbers.
            return listOf(
                RawCluster(
                    coreIds = (0 until coreCount).toList(),
                    minKhz = null,
                    maxKhz = null,
                    governor = null,
                )
            )
        }
        return grouped.entries
            .sortedByDescending { it.key }
            .map { entry ->
                val first = entry.value.first()
                RawCluster(
                    coreIds = entry.value.sorted(),
                    minKhz = SysFs.readLong(
                        "/sys/devices/system/cpu/cpu$first/cpufreq/cpuinfo_min_freq"
                    ),
                    maxKhz = entry.key,
                    governor = SysFs.readText(
                        "/sys/devices/system/cpu/cpu$first/cpufreq/scaling_governor"
                    ),
                )
            }
    }

    /**
     * Naming follows topology, not marketing.
     *
     * A lone fastest core is a "Prime" and the rest are Gold and Silver, which
     * is how Qualcomm and the phone press describe 1+3+4 parts. A symmetric
     * split is Big and Little. One domain is just "CPU". Getting this wrong is
     * cosmetic, but a user comparing against a spec sheet notices immediately.
     */
    private fun label(raw: List<RawCluster>): List<ClusterSpec> {
        val sorted = raw.sortedByDescending { it.maxKhz ?: 0L }
        if (sorted.size == 1) {
            return listOf(sorted[0].toSpec("CPU"))
        }
        val primeLed = sorted.first().coreIds.size == 1
        val names = if (primeLed) {
            listOf("Prime", "Gold", "Silver", "Tiny")
        } else {
            listOf("Big", "Mid", "Little", "Tiny")
        }
        return sorted.mapIndexed { index, cluster ->
            val name = when {
                index < names.size -> names[index]
                else -> "Cluster ${index + 1}"
            }
            // Two clusters means Big/Little, never Big/Mid.
            val corrected = if (sorted.size == 2 && !primeLed && index == 1) "Little" else name
            cluster.toSpec(corrected)
        }
    }

    private data class RawCluster(
        val coreIds: List<Int>,
        val minKhz: Long?,
        val maxKhz: Long?,
        val governor: String?,
    ) {
        fun toSpec(label: String) = ClusterSpec(label, coreIds, minKhz, maxKhz, governor)
    }
}
