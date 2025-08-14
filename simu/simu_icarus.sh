
design_path="../source/design/"
verif_path="../source/verif/"

dut="fifo"

echo "################################################"
echo "### Preparing Simulation"
echo "################################################"
iverilog -o sim.out \
$design_path/fifo.v \
$verif_path/fifo_test.sv

echo "################################################"
echo "### Running Simulation..."
echo "################################################"
vvp sim.out

echo DONE!