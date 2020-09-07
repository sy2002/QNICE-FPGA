# This extra tcl-script enables ILA debugging.

# First determine which nets are marked for debugging.
set dbgs [get_nets -hierarchical -filter {MARK_DEBUG}]

if {[llength $dbgs] == 0} {
   return
}

foreach d $dbgs {
   # name is root name of a bus, index is the bit index in the
   # bus
   set name [regsub {\[[[:digit:]]+\]$} $d {}]
   set index [regsub {^.*\[([[:digit:]]+)\]$} $d {\1}]
   if {[string is integer -strict $index]} {
      if {![info exists max($name)]} {
          set max($name) $index
          set min($name) $index
      } elseif {$index > $max($name)} {
          set max($name) $index
      } elseif {$index < $min($name)} {
          set min($name) $index
      }
   } else {
      set max($name) -1
   }
   if {![info exists clocks($name)]} {
      set paths [get_timing_paths -through $d]
      if {[llength $paths] > 0} {
          set clocks($name) [get_property ENDPOINT_CLOCK [lindex $paths 0]]
          puts "name=$name, paths=$paths, clocks=$clocks($name)"
          if {![info exists clock_list($clocks($name))]} {
              # found a new clock
              set clock_list($clocks($name)) [list $name]
          } else {
              lappend clock_list($clocks($name)) $name
          }
      }
   }
}

# Now sort them according to clock groups
foreach c [array names clock_list] {
   set clk [get_clocks $c]
   set ila_inst u_ila_$c
   set clk_net [get_nets -of_objects [get_pins [get_property SOURCE_PINS $clk]]]

   puts "Creating ILA $ila_inst with clock $clk_net"
   ##################################################################
   # create ILA and connect its clock
   create_debug_core  $ila_inst        ila
   set_property       C_DATA_DEPTH     2048 [get_debug_cores $ila_inst]
   set_property       port_width 1     [get_debug_ports $ila_inst/clk]
   connect_debug_port $ila_inst/clk    $clk_net
   ##################################################################

   # add probes
   set nprobes 0
   foreach n [lsort $clock_list($c)] {
       set nets {}
       if {$max($n) < 0} {
           lappend nets [get_nets $n]
       } else {
           # n is a bus name
           for {set i $min($n)} {$i <= $max($n)} {incr i} {
               lappend nets [get_nets $n[$i]]
           }
       }
       set prb probe$nprobes
       if {$nprobes > 0} {
           create_debug_port $ila_inst probe
       }
       set_property port_width [llength $nets] [get_debug_ports $ila_inst/$prb]
       connect_debug_port $ila_inst/$prb $nets
       puts " ... nets: $nets."
       incr nprobes
   }
   puts " ... TOTAL $nprobes probes."
}

##################################################################
puts "implement_debug_core"
implement_debug_core

##################################################################
puts "write_debug_probes"
write_debug_probes -force vga_test.ltx

