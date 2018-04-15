#!/bin/bash
set -e
set -x
# repeat 1980 nyears times
nyears=1

# if not spinup specify the folder with driving data
spinup=false
original_driving_data_dir=../../../../../NEMO_OFFLINE_DRIVING_from_CORDEX_NA_044degt
prepared_driving_data_dir=./driving_data/


start_year=1980


# timestep is 30 min
steps_in_day=$(echo "48" | bc -l)   

timestep_sec=$(echo "24 * 3600 / ${steps_in_day}" | bc -l)


output_freq_steps=${steps_in_day}


ln_rstart=.false.



# start step
nn_it000=1


the_date=${start_year}0101

ln_tsd_init=.true.

isleap=0

next_year=${start_year}


#============================================================================================


ndays_per_yea=365
if [ "${spinup}" = "true" ]; then
	prepared_driving_data_dir="./"
	ndays_per_year=365
else
      
	if [ "${isleap}" = "1" ]; then
		ndays_per_year=$(cal ${start_year} | egrep -v "[a-z]|[0-9][0-9][0-9]" | wc -w)
	fi
fi

# nn_itend=$(echo "${steps_in_day} * 150" | bc -l)  #$(echo "${nn_it000} + ${steps_in_day} * ${ndays_per_year} - 1" | bc -l)

nn_itend=$(echo "${nn_it000} + ${steps_in_day} * ${ndays_per_year} - 1" | bc -l)

prepare_driving_data(){

	local i

 	local year=$1
		
 	local varnames=(AD N4 UU VV PR SN TT HU)
	local dest_filenames=(radlw.nc radsw.nc u10.nc v10.nc precip.nc snow.nc t2.nc q2.nc)


	cd ${prepared_driving_data_dir}
	
	local v dest	
	for i in $(seq 0 $((${#varnames[@]} - 1))); do
  		echo ${i}, ${varnames[$i]} "=>" ${dest_filenames[$i]}
		v=${varnames[$i]}
		dest=${dest_filenames[$i]}
		ln -sf ${original_driving_data_dir}/${v}/${v}_${year}.nc  ${dest}
	done

	cd -
}



prepare_driving_data_and_double_snow(){
	prepare_driving_data $1
	cd  ${prepared_driving_data_dir}

	rm -f tmp.nc
	ncks -A snow.nc tmp.nc
	ncks -A precip.nc tmp.nc

	# Double the snow and change the total precip accordingly
	ncap2 -s "PR=PR+SN;SN=2*SN;" tmp.nc -O tmp.nc
	
	rm snow.nc precip.nc
	
	ln -sf tmp.nc snow.nc
	ln -sf tmp.nc precip.nc
	
	cd -
}




for i in $(seq 0 ${nyears}); do 

	
	# get the current start date (Jan 1st of the corresponding year)
	the_date="$(echo "${start_year} + ${i}" | bc -l)"0101

	echo "Start date: ${the_date}"



	restart_prefix_in=GLK_$(printf "%08d" $(echo "${nn_it000} - 1" | bc -l) )_restart
	restart_prefix_out=GLK_$(printf "%08d" ${nn_itend})_restart

	# ---launch the current year if required
	if [ $(ls | grep ${restart_prefix_out} | wc -w) -gt 0 ]; then
		
		echo "It looks like ${the_date} is done, will not redo!"
	else
		# Generate namelist for the current month
		sed -e "s/STARTSTEP/${nn_it000}/" namelist.template |\
		sed -e "s/ENDSTEP/${nn_itend}/" |\
		sed -e "s/RESTARTFLAG/${ln_rstart}/" |\
		sed -e "s/RESTARTFILEPREFIX/${restart_prefix_in}/" |\
		sed -e "s/FLAGINITTSFROMFILES/${ln_tsd_init}/" |\
		sed -e "s/STARTDATE/${the_date}/" |\
		sed -e "s/ISLEAPYEAR/${isleap}/" |\
		sed -e "s/OUTPUTFREQUENCYTIMESTEPS/${output_freq_steps}/" |\
		sed -e "s/TIMESTEPSEC/${timestep_sec}/" |\
		sed -e "s|DRIVINGDATAROOTDIR|${prepared_driving_data_dir}|" > namelist

		# Prepare namelist for the ice model
		sed -e "s/RESTARTFILEPREFIX/${restart_prefix_in}\_ice/" namelist_ice.template > namelist_ice
	
		# Prepare the driving data for the next year of the simulation
		if [ "${spinup}" = "false" ]; then
			prepare_driving_data ${next_year}
                else
                        # Driving data does not change from year to year in case of spinup
                        if [ "${next_year}" = "${start_year}"  ]; then
                             prepare_driving_data ${next_year}
                        fi
		fi


		# run a year
		echo Running $(echo "${i} + ${start_year}" | bc -l)
		mpirun -np $1 ./opa >& opa.log
                
                # check model exit code
                rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi
	fi



	# prepare values for the next chunk
	nn_it000=$(echo "${nn_itend} + 1" | bc -l)


	ln_rstart=.true.
	ln_tsd_init=.false.

	
	# -- prepare driving data for the next year if not in spinup mode -- 
	if [ "${spinup}" = "false" ]; then
		next_year=$(echo "${start_year} + ${i} + 1" | bc -l)
		ndays_per_year=$(cal ${next_year} |egrep -v "[a-z]|[0-9][0-9][0-9]" |wc -w)

		echo "Not a spinup, preparing driving data for ${next_year}"
		
	else
		echo "Spinup"	
	fi	

	nn_itend=$(echo "${nn_it000} + ${steps_in_day} * ${ndays_per_year} - 1" | bc -l)

	
done



