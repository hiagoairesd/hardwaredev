
design_path="../source/design/"
verif_path="../source/verif/"

dut=$1

# 1. Compilar
echo "################################################"
echo "### Compilation starting..."
echo "################################################"
xrun -compile -access +rwc \
$design_path/$dut.v \
$verif_path/$dut_test.sv

# 2. Elaborar
echo "################################################"
echo "### Elaboration starting..."
echo "################################################"
xrun -elaborate ../source/verif/fifo_test.sv -access +rwc

# 3. Simular (com script TCL)
echo "################################################"
echo "### Simulation starting..."
echo "################################################"
xrun -R -input ./simu.tcldut

echo this is the dut $dut