set_param project.enableReportConfiguration 0
load_feature core
current_fileset
xsim {xsim_test} -wdb {xsim_database.wdb} -autoloadwcfg -tclbatch {xsim_options.tcl}
