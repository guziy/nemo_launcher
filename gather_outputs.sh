

outdir=zdf_gls_dt_and_sbc_5min

nprocs=20


out_file_prefix=GLK_1d_


grid_types=(grid_T grid_U grid_V grid_W icemoa icemod)

#===============================================================

# create the output directory

if [ ! -d ${outdir}  ]; then

	echo "${outdir} does not exist, creating ..."
	mkdir ${outdir}
fi


for gtype in ${grid_types[@]}; do
	echo ${gtype}
	
	interval_prefix_list=$(ls ${out_file_prefix}*${gtype}_0001*)

	for ipref in ${interval_prefix_list[@]}; do
		prefix=${ipref%_*}
		echo "${ipref} => ${prefix}"
		../../../TOOLS/REBUILD_NEMO/rebuild_nemo ${prefix} ${nprocs} 
		mv ${prefix}.nc ${outdir}		
	done

done



