process FUSION_OVERVIEW {
    tag 'combined'
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container 'docker.io/jiangyanyu/fusion-report_beautifulsoup4_click_colorlog_pruned:78488bd99166aa9a'

    input:
    path(filtered_files)
    val(samples)
    path(overview_script)

    output:
    path 'fusion_overview.xlsx', emit: workbook

    script:
    def samples_json = groovy.json.JsonOutput.toJson(samples)
    """
    cat > samples.json <<'END_SAMPLES'
    ${samples_json}
    END_SAMPLES

    python ${overview_script} \\
        --arriba arriba_filtered.tsv \\
        --starfusion starfusion_filtered.tsv \\
        --samples samples.json \\
        --output fusion_overview.xlsx
    """

    stub:
    """
    touch fusion_overview.xlsx
    """
}
