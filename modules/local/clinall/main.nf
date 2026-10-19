process CLINALL {
    tag 'combined'
    label 'process_medium'

    container 'docker.io/ukwgenommedizin/clinall-v2:dev'
    containerOptions {
        workflow.containerEngine == 'singularity' ?
            "--bind ${clinall_ref}:/app/data:ro" :
            "--entrypoint '' --volume ${clinall_ref}:/app/data:ro"
    }

    input:
    path(counts)
    val(clinall_ref)

    output:
    path 'outputs', emit: results
    path 'versions.yml', emit: versions

    script:
    """
    # Numba's default cache locations may not be writable inside the container.
    export NUMBA_CACHE_DIR="\${PWD}/.numba_cache"
    mkdir -p "\$NUMBA_CACHE_DIR"

    # ClinALL expects a two-column expression table. Drop featureCounts
    # metadata/comment rows and keep the gene identifier and final count column.
    mkdir -p clinall_counts
    for counts_file in *.featureCounts.tsv; do
        awk -F '\t' 'BEGIN { OFS = "\t" } !/^#/ { if (!header) { print "gene_od", "raw"; header = 1; next } print \$1, \$NF }' \\
            "\$counts_file" > "clinall_counts/\$counts_file"
    done

    python /app/run.py \\
        --batch-root clinall_counts \\
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
