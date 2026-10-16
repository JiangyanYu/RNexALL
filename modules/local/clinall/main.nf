process CLINALL {
    tag 'combined'
    label 'process_medium'

    container 'docker.io/ukwgenommedizin/clinall-v2:dev'
    containerOptions {
        workflow.containerEngine == 'singularity' ?
            "--bind ${clinall_ref}:/app/data:ro" :
            "--entrypoint /bin/bash --volume ${clinall_ref}:/app/data:ro"
    }

    input:
    path(counts)
    val(clinall_ref)

    output:
    path 'outputs', emit: results
    path 'versions.yml', emit: versions

    script:
    """
    python /app/run.py \\
        --batch-root . \\
        --batch-pattern "*.featureCounts.tsv" \\
        --batch-mode combined \\
        --batch-output-dir outputs \\
        --expr-col raw \\
        --umap

    printf '"%s":\\n    clinall: "dev"\\n' "${task.process}" > versions.yml
    """

    stub:
    """
    mkdir -p outputs
    printf '"%s":\\n    clinall: "dev"\\n' "${task.process}" > versions.yml
    """
}
