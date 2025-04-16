#!/bin/bash

# Function to run stress-ng, turbostat, and extract CorWatt and PkgWatt
run_test() {
    local maxcore=$1
    local flag=$2	


    # Run stress-ng in the background
    tmpfile=$(mktemp)
    #   /home/amd/stress-ng/stress-ng -c 0 -l "$load" &
    #    /home/amd/stress-ng/stress-ng --cpu 0 --cpu-method fft -l "$load" &
    if [ "$flag" -eq 1 ]; then
    numactl -C 0-$((maxcore-1))  /home/amd/stress-ng/stress-ng --matrix $maxcore --matrix-size 128 --metrics-brief -t 1m  > "$tmpfile" &
    

    elif [ "$flag" -eq 0 ]; then
    /home/amd/stress-ng/stress-ng --matrix $maxcore --matrix-size 128 --metrics-brief -t 1m  > "$tmpfile" &

    	else
	    echo "unknown flag: $flag"
	fi

    # Wait for 10 seconds
    sleep 10

    #./cpufreq.sh & 

    # Run turbostat and capture the output
    turbostat_output=$(turbostat -n 1 -S)

    # Extract CorWatt and PkgWatt values using awk
    corwatt=$(echo "$turbostat_output" | awk 'NR>1 {print $13}' | head -n 1)
    pkgwatt=$(echo "$turbostat_output" | awk 'NR>1 {print $14}' | head -n 1)

    # Save the values to variables with the load appended
    eval "corwatt_$maxcore=$corwatt"
    eval "pkgwatt_$maxcore=$pkgwatt"



    clkfreq_allcore=$(grep "^[c]pu MHz" /proc/cpuinfo | head -n $maxcore)
    average_clkfreq=$(echo "$clkfreq_allcore" | awk -F: '{ total += $2; count++ } END { print total/count }')
    eval "average_clkfreq_$maxcore=$average_clkfreq"

    sleep 5

    # Kill the stress-ng process
    pkill stress-ng


	# Kill the cpufreq.sh script
    pkill -f cpufreq.sh


    sleep 10

    # Extract bogo ops/s value from stress-ng output, this greps the output is the bogoops/s (usr+sys)
    bogoops_usr_sys=$(awk '/stress-ng: metrc:/ {print $NF}' "$tmpfile" | tail -n 1)

    #this extracts the raw bogoops number
    bogoops=$(awk '/matrix/ && $5 ~ /^[0-9]+$/ {print $5}' "$tmpfile")


    # Save the bogo ops/s value to a variable with the load appended
    eval "bogoops_usr_sys_$maxcore=$bogoops_usr_sys"
    eval "bogoops_$maxcore=$bogoops"
    rm "$tmpfile"



# Copy cpu_frequencies.csv to cpu_frequencies_$maxcore.csv
    #cp cpu_frequencies.csv cpu_frequencies_$maxcore.csv


    sleep 10
}

# Loop through number of threads
for maxcore in $(seq 12 12 144); do
    run_test "$maxcore" 1
done

# Print the results in a table format
echo "====================  Results with NUMA CTL ======================="
echo "MaxCore   CorWatt   PkgWatt   Bogoops/s(usr+sys)	Bogoops		average_clkfreq"
for maxcore in $(seq 12 12 144); do
        eval "echo -e  $maxcore		\$corwatt_$maxcore 	\$pkgwatt_$maxcore 	\$bogoops_usr_sys_$maxcore	\$bogoops_$maxcore	\$average_clkfreq_$maxcore"
done




# Loop through number of threads
for maxcore in $(seq 12 12 144); do
    run_test "$maxcore" 0
done

# Print the results in a table format
echo "====================  Results with free run  ======================="
echo "MaxCore   CorWatt   PkgWatt   Bogoops/s(usr+sys)	Bogoops	"
for maxcore in $(seq 12 12 144); do
        eval "echo -e  $maxcore		\$corwatt_$maxcore 	\$pkgwatt_$maxcore 	\$bogoops_usr_sys_$maxcore	\$bogoops_$maxcore"
done
