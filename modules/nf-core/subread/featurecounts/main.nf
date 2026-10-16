process SUBREAD_FEATURECOUNTS {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/subread:2.1.1--h577a1d6_0' :
        'quay.io/biocontainers/subread:2.1.1--h577a1d6_0' }"

    input:
    tuple val(meta), path(bam), path(annotation)

    output:
    tuple val(meta), path('*.featureCounts.tsv'), emit: counts
    tuple val(meta), path('*.featureCounts.tsv.summary'), emit: summary
    path 'versions.yml', emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def paired_end = meta.single_end ? '' : '-p'
    def strandedness = meta.strandedness == 'forward' ? 1 : meta.strandedness == 'reverse' ? 2 : 0
    """
    featureCounts \\
        ${args} \\
        ${paired_end} \\
        -T ${task.cpus} \\
        -a ${annotation} \\
        -s ${strandedness} \\
        -o ${prefix}.featureCounts.tsv \\
        ${bam}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        subread: "\$(featureCounts -v 2>&1 | sed -n 's/^featureCounts v//p' | head -n1 | tr -d '\r')"
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.featureCounts.tsv
    touch ${prefix}.featureCounts.tsv.summary

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        subread: "\$(featureCounts -v 2>&1 | sed -n 's/^featureCounts v//p' | head -n1 | tr -d '\r')"
    END_VERSIONS
    """
}
