onbreak {quit -f}
onerror {quit -f}

vsim  -lib xil_defaultlib gig_ethernet_pcs_pma_0_opt

set NumericStdNoWarnings 1
set StdArithNoWarnings 1

do {wave.do}

view wave
view structure
view signals

do {gig_ethernet_pcs_pma_0.udo}

run 1000ns

quit -force
