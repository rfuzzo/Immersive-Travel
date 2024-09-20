@echo off

echo "Generating graphs"
:: iterate over all .dot files in the current directory
for %%f in (*.dot) do dot -Tpng "%%f" -O

echo "Graphs generated"

pause