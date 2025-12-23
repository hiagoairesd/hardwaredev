
design_path="../source/design/LASD/mod3"
verif_path="../source/verif"

dut=${1:-fifo}

echo "################################################"
echo "###   Running Compilation and Elaboration..."
echo "################################################"

iverilog -o ${dut}.out \
$design_path/${dut}.v \
$verif_path/${dut}_test.sv


echo "################################################"
echo "###   Running Simulation..."
echo "################################################"
vvp ${dut}.out

echo "###   Finished Simulation ######################"