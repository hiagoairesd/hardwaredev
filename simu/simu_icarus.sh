
design_path="../source/design"
verif_path="../source/verif"

dut=${1:-fifo}

echo "################################################"
echo "###   Running Compilation and Elaboration..."
echo "################################################"

iverilog -o ${dut}.out \
$design_path/*.v \
$design_path/LASD/mod1/*.v \
$verif_path/${dut}_test.sv


echo "################################################"
echo "###   Running Simulation..."
echo "################################################"
vvp ${dut}.out

echo COMPLETED!