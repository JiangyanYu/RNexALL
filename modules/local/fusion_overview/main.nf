process FUSION_OVERVIEW {
    tag 'combined'
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container 'docker.io/jiangyanyu/fusion-report_beautifulsoup4_click_colorlog_pruned:78488bd99166aa9a'

    input:
    path(arriba_filtered)
    path(starfusion_filtered)
    path(arriba_merged)
    path(starfusion_merged)
    val(samples)
    path(overview_script)

    output:
    path 'fusion_overview.xlsx',     emit: filtered_workbook
    path 'fusion_overview_raw.xlsx', emit: raw_workbook

    script:
    def samples_json = groovy.json.JsonOutput.toJson(samples)
    """
    cat > samples.json <<'END_SAMPLES'
    ${samples_json}
    END_SAMPLES

    python ${overview_script} \\
        --arriba ${arriba_filtered} \\
        --starfusion ${starfusion_filtered} \\
        --samples samples.json \\
        --output fusion_overview.xlsx

    python ${overview_script} \\
        --arriba ${arriba_merged} \\
        --starfusion ${starfusion_merged} \\
        --samples samples.json \\
        --output fusion_overview_raw.xlsx
    """

    stub:
    """
    touch fusion_overview.xlsx
    touch fusion_overview_raw.xlsx
    """
}
