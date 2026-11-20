process MERGE_FUSIONS {
    tag "$caller"
    label 'process_single'

    input:
    tuple val(caller), path(fusion_files), path(whitelist_file)

    output:
    path "${caller}_merged.tsv",   emit: merged
    tuple val(caller), path("${caller}_filtered.tsv"), emit: filtered

    script:
    if (caller == 'arriba') {
        """
        awk -F '\\t' -v OFS='\\t' '
            FNR == 1 {
                if (NR == 1) {
                    print \$0, "sample", "sum_split_reads", "fusions"
                    gene1 = gene2 = 0
                    for (i = 1; i <= NF; i++) {
                        column = \$i
                        sub(/^#/, "", column)
                        if (column == "gene1") gene1 = i
                        if (column == "gene2") gene2 = i
                    }
                    if (!gene1 || !gene2) {
                        print "ERROR: Arriba fusion file is missing gene1 or gene2" > "/dev/stderr"
                        exit 1
                    }
                }
                split_reads1 = split_reads2 = 0
                for (i = 1; i <= NF; i++) {
                    if (\$i == "split_reads1") split_reads1 = i
                    if (\$i == "split_reads2") split_reads2 = i
                }
                if (!split_reads1 || !split_reads2) {
                    print "ERROR: Arriba fusion file is missing split_reads1 or split_reads2" > "/dev/stderr"
                    exit 1
                }
                next
            }
            {
                sample = FILENAME
                sub(/^.*\\//, "", sample)
                sub(/\\.arriba\\.fusions\\.tsv\$/, "", sample)
                print \$0, sample, (\$split_reads1 + \$split_reads2), (\$gene1 "::" \$gene2)
            }
        ' ${fusion_files} > arriba_merged.tsv

        awk -F '\\t' '
            BEGIN {
                while ((getline line < "${whitelist_file}") > 0) {
                    whitelist_lines++
                    sub(/\\r\$/, "", line)
                    if (whitelist_lines == 1) {
                        if (line != "type,value") {
                            print "ERROR: Arriba whitelist CSV must have a type,value header" > "/dev/stderr"
                            exit 1
                        }
                        continue
                    }
                    fields = split(line, whitelist_fields, ",")
                    if (fields != 2 || whitelist_fields[2] == "" ||
                        (whitelist_fields[1] != "fusion" && whitelist_fields[1] != "gene")) {
                        print "ERROR: Invalid Arriba whitelist CSV row " whitelist_lines > "/dev/stderr"
                        exit 1
                    }
                    if (whitelist_fields[1] == "fusion") {
                        whitelist_fusions[whitelist_fields[2]] = 1
                    } else {
                        whitelist_genes[whitelist_fields[2]] = 1
                    }
                }
                close("${whitelist_file}")
                if (!whitelist_lines) {
                    print "ERROR: Arriba whitelist CSV is empty" > "/dev/stderr"
                    exit 1
                }
            }
            NR == 1 {
                for (i = 1; i <= NF; i++) {
                    column = \$i
                    sub(/^#/, "", column)
                    if (column == "gene1") gene1 = i
                    if (column == "gene2") gene2 = i
                    if (column == "type") type = i
                    if (column == "sum_split_reads") split_reads = i
                    if (column == "fusions") fusions = i
                }
                if (!gene1 || !gene2 || !type || !split_reads || !fusions) {
                    print "ERROR: Arriba merged file is missing a required filtering column" > "/dev/stderr"
                    exit 1
                }
                print
                next
            }
            whitelist_fusions[\$fusions] ||
                whitelist_genes[\$gene1] || whitelist_genes[\$gene2] ||
                (\$split_reads >= 10 && tolower(\$type) ~ /translocation/)
        ' arriba_merged.tsv > arriba_filtered.tsv
        """
    } else if (caller == 'starfusion') {
        """
        awk -F '\\t' -v OFS='\\t' '
            FNR == 1 {
                if (NR == 1) print \$0, "sample"
                junction_read_count = 0
                for (i = 1; i <= NF; i++) {
                    if (\$i == "JunctionReadCount") junction_read_count = i
                }
                if (!junction_read_count) {
                    print "ERROR: STAR-Fusion file is missing JunctionReadCount" > "/dev/stderr"
                    exit 1
                }
                next
            }
            {
                sample = FILENAME
                sub(/^.*\\//, "", sample)
                sub(/\\.starfusion\\.fusion_predictions\\.tsv\$/, "", sample)
                print \$0, sample
            }
        ' ${fusion_files} > starfusion_merged.tsv

        awk -F '\\t' '
            NR == 1 {
                for (i = 1; i <= NF; i++) {
                    if (\$i == "JunctionReadCount") junction_read_count = i
                }
                if (!junction_read_count) {
                    print "ERROR: STAR-Fusion merged file is missing JunctionReadCount" > "/dev/stderr"
                    exit 1
                }
                print
                next
            }
            \$junction_read_count >= 10
        ' starfusion_merged.tsv > starfusion_filtered.tsv
        """
    } else {
        error("Unsupported fusion caller for downstream analysis: ${caller}")
    }

    stub:
    if (caller == 'arriba') {
        """
        printf '#gene1\\tgene2\\tsplit_reads1\\tsplit_reads2\\tsample\\tsum_split_reads\\tfusions\\n' > arriba_merged.tsv
        cp arriba_merged.tsv arriba_filtered.tsv
        """
    } else {
        """
        printf '#FusionName\\tJunctionReadCount\\tsample\\n' > starfusion_merged.tsv
        cp starfusion_merged.tsv starfusion_filtered.tsv
        """
    }
}
