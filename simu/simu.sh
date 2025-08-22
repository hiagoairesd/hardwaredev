
design_path="../source/design/"
verif_path="../source/verif/"

dut=${1:-fifo}

# 1. Compilar
echo "################################################"
echo "### Compilation starting..."
echo "################################################"
xrun -compile -access +rwc \
$design_path/${dut}.v \
$verif_path/${dut}_test.sv

# 2. Elaborar
echo "################################################"
echo "### Elaboration starting..."
echo "################################################"
xrun -elaborate $verif_path/${dut}_test.sv -access +rwc

# 3. Simular (com script TCL)
echo "################################################"
echo "### Simulation starting..."
echo "################################################"
xrun -R -input ./simu.tcl
