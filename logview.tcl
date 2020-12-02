#!/usr/bin/env wish
################################################################################
# Log Viewer                                                                   #
#                                                                              #
# Copyright (C) 2020 J.C. Fields (jcfields@jcfields.dev).                      #
#                                                                              #
# Permission is hereby granted, free of charge, to any person obtaining a copy #
# of this software and associated documentation files (the "Software"), to     #
# deal in the Software without restriction, including without limitation the   #
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or  #
# sell copies of the Software, and to permit persons to whom the Software is   #
# furnished to do so, subject to the following conditions:                     #
#                                                                              #
# The above copyright notice and this permission notice shall be included in   #
# all copies or substantial portions of the Software.                          #
#                                                                              #
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR   #
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,     #
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE  #
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER       #
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING      #
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS #
# IN THE SOFTWARE.                                                             #
################################################################################

set log_directory /var/log
set file_filter {*.log *_log}
set polling_interval 1000

# window size
set default_width 1000
set default_height 600

################################################################################
# Create main window functions                                                 #
################################################################################

proc make_window {width height} {
	# centers window
	set x [expr {([winfo vrootwidth .] - $width) / 2}]
	set y [expr {([winfo vrootheight .] - $height) / 2}]

	wm title . {Log Viewer}
	wm geometry . ${width}x${height}+${x}+${y}
}

proc make_widgets {root} {
	ttk::frame .fr
	pack .fr -fill both -expand yes

	add_path_frame
	add_files_treeview $root
	add_tools_frame $root
	add_lines_listbox
	add_labels_frame
	add_line_textarea

	grid rowconfigure .fr 1 -weight 1
	grid columnconfigure .fr 1 -weight 1

	update_widgets {}
}

proc add_path_frame {} {
	ttk::frame .fr.path
	grid .fr.path -row 0 -column 0 -padx 5 -pady 5 -sticky news

	ttk::button .fr.path.dir -text {Open...} -takefocus 0 -command {
		set path [tk_chooseDirectory -initialdir $::log_directory \
			-title {Choose a directory}]

		if {$path ne {}} {
			if {[file readable $path] && [file isdirectory $path]} {
				set ::log_directory $path
				load_treeview $path $::file_filter
			} else {
				tk_messageBox -icon error -type ok \
					-message {Invalid path} \
					-detail {The specified path is not a valid directory.}
			}
		}
	}

	grid .fr.path.dir -row 0 -column 0 -sticky w
}

proc add_files_treeview {root} {
	ttk::frame .fr.files
	grid .fr.files -row 1 -column 0 -rowspan 3 -padx 5 -pady 5 -sticky news

	ttk::treeview .fr.files.tr -selectmode browse -show tree \
		-yscrollcommand {.fr.files.sb set}
	ttk::scrollbar .fr.files.sb -orient v -command {.fr.files.tr yview}

	bind .fr.files.tr <<TreeviewSelect>> {
		set n [%W selection]

		if {$n ne {}} {
			set path [%W item $n -value]

			clear_search
			load_log $path
			update_widgets $path

			watch_file $path {}
		}
	}

	grid .fr.files.tr -row 0 -column 0 -sticky news
	grid .fr.files.sb -row 0 -column 1 -sticky ns

	grid rowconfigure .fr.files 0 -weight 1
	grid columnconfigure .fr.files 0 -weight 1

	load_treeview $root $::file_filter
}

proc add_tools_frame {path} {
	ttk::frame .fr.tools
	grid .fr.tools -row 0 -column 1 -padx 5 -pady 5 -sticky news

	ttk::label .fr.tools.label -text {Filter: }
	ttk::entry .fr.tools.filter -width 30
	bind .fr.tools.filter <KeyRelease> {
		reload_lines
		update_line
	}

	ttk::button .fr.tools.reload -text Reload -takefocus 0 -command {
		set n [.fr.files.tr selection]

		if {$n ne {}} {
			reload_log [.fr.files.tr item $n -value]
		}
	}

	grid .fr.tools.label -row 0 -column 0 -sticky s
	grid .fr.tools.filter -row 0 -column 1 -sticky s
	grid .fr.tools.reload -row 0 -column 2 -sticky e

	grid columnconfigure .fr.tools 2 -weight 1
}

proc add_lines_listbox {} {
	ttk::frame .fr.lines
	grid .fr.lines -row 1 -column 1 -padx 5 -pady 5 -sticky news

	tk::listbox .fr.lines.lb -yscrollcommand {.fr.lines.sb set}
	ttk::scrollbar .fr.lines.sb -orient v -command {.fr.lines.lb yview}
	.fr.lines.lb insert end {}

	bind .fr.lines.lb <<ListboxSelect>> {
		set n [%W curselection]

		if {$n ne {}} {
			set line [%W get $n]
			set size [%W size]

			show_line $n $line $size
		}
	}

	grid .fr.lines.lb -row 0 -column 0 -sticky news
	grid .fr.lines.sb -row 0 -column 1 -sticky ns

	grid rowconfigure .fr.lines 0 -weight 1
	grid columnconfigure .fr.lines 0 -weight 1
}

proc add_labels_frame {} {
	ttk::frame .fr.labels
	grid .fr.labels -row 2 -column 1 -padx 5 -pady 5 -sticky news

	ttk::label .fr.labels.line -width 30
	ttk::label .fr.labels.size -width 30
	ttk::label .fr.labels.mtime -width 30

	grid .fr.labels.line -row 0 -column 0
	grid .fr.labels.size -row 0 -column 1
	grid .fr.labels.mtime -row 0 -column 2

	grid columnconfigure .fr.labels 1 -weight 1
}

proc add_line_textarea {} {
	ttk::frame .fr.text
	grid .fr.text -row 3 -column 1 -padx 5 -pady 5 -sticky news

	text .fr.text.tb -height 15 -yscrollcommand {.fr.text.sb set}
	ttk::scrollbar .fr.text.sb -orient v -command {.fr.text.tb yview}

	grid .fr.text.tb -row 0 -column 0 -sticky news
	grid .fr.text.sb -row 0 -column 1 -sticky ns

	grid rowconfigure .fr.text 0 -weight 1
	grid columnconfigure .fr.text 0 -weight 1
}

################################################################################
# Update main window functions                                                 #
################################################################################

proc clear_search {} {
	.fr.tools.filter delete 0 end
}

proc load_treeview {root filters} {
	.fr.files.tr delete [.fr.files.tr children {}]
	insert_node 0 {} $root $filters
}

proc insert_node {depth parent path filters} {
	set logs {}

	foreach filter $filters {
		lappend logs {*}[glob -nocomplain -type {f r} $path/$filter]
	}

	if {[llength $logs] > 0} {
		set name [file tail [file dirname [lindex $logs 0]]]

		if {$depth == 0} {
			set node {}
		} else {
			set node [.fr.files.tr insert $parent end -text $name -open true]
		}

		set sub_dirs [glob -nocomplain -type {d r} $path/*]
		incr depth

		# directories sorted before files
		foreach sub_dir [lsort -dictionary $sub_dirs] {
			# recursively crawls subdirectories
			insert_node $depth $node $sub_dir $filters
		}

		foreach log [lsort -dictionary $logs] {
			.fr.files.tr insert $node end -text [file tail $log] -value $log
		}
	}
}

proc update_widgets {path} {
	# checks if directory node selected
	if {$path eq {}} {
		.fr.labels.line configure -text {}
		.fr.labels.size configure -text {}
		.fr.labels.mtime configure -text {}

		.fr.tools.filter configure -state disabled
		.fr.tools.reload configure -state disabled
	} else {
		update_line

		.fr.labels.size configure -text [format_size $path]
		.fr.labels.mtime configure -text [format_mtime $path]

		.fr.tools.filter configure -state normal
		.fr.tools.reload configure -state normal
	}
}

proc update_line {} {
	set size [.fr.lines.lb size]
	.fr.labels.line configure -text [format_line $size $size]
}

proc show_line {n line size} {
	# prevents error if listbox has no items
	if {$n ne {}} {
		.fr.text.tb delete 0.0 end
		.fr.text.tb insert end $line

		.fr.labels.line configure -text [format_line $n $size]
	}
}

proc load_log {path} {
	.fr.lines.lb delete 0 end
	.fr.text.tb delete 0.0 end

	if {$path ne {}} {
		set filter [.fr.tools.filter get]
		set ::log_lines [read_log $path]

		.fr.lines.lb insert end {*}[filter_lines $filter $::log_lines]
	}
}

proc reload_log {path} {
	if {$path ne {}} {
		set new_lines [read_log $path]
		set new_size [llength $new_lines]
		set old_size [llength $::log_lines]

		set filter [.fr.tools.filter get]

		if {$new_size > $old_size} {
			# inserts new lines at top of listbox
			set end [expr $new_size - $old_size - 1]
			set lines [lrange $new_lines 0 $end]

			.fr.lines.lb insert 0 {*}[filter_lines $filter $lines]
		} else {
			# reloads entire file if same size or smaller than previous load
			set ::log_lines $new_lines

			.fr.lines.lb delete 0 end
			.fr.lines.lb insert end {*}[filter_lines $filter $::log_lines]
		}

		update_widgets $path
	}
}

proc reload_lines {} {
	set filter [.fr.tools.filter get]

	.fr.lines.lb delete 0 end
	.fr.lines.lb insert end {*}[filter_lines $filter $::log_lines]
}

################################################################################
# File/directory functions                                                     #
################################################################################

proc read_log {path} {
	set log [read [open $path r]]
	set lines [split [string trimright $log] \n]

	return [lreverse $lines]
}

proc filter_lines {filter lines} {
	if {$filter eq {}} {
		return $lines
	}

	# escapes special characters
	# literal * and ? not allowed, used as wildcards
	set filter [string map {\\ \\\\} $filter]
	set filter [string map {\[ \\[} $filter]
	set filter [string map {\] \\]} $filter]

	set filtered_lines {}

	foreach line $lines {
		if [string match *$filter* [string tolower $line]] {
			lappend filtered_lines $line
		}
	}

	return $filtered_lines
}

proc watch_file {path mtime} {
	if {$path ne {}} {
		if {$mtime eq {}} {
			if [info exists ::poll] {
				after cancel $::poll
			}

			watch_file $path [file mtime $path]
		} else {
			if {[file mtime $path] != $mtime} {
				reload_log $path
				watch_file $path {}
			} else {
				set ::poll [after $::polling_interval [info level 0]]
			}
		}
	}
}

################################################################################
# Formatting functions                                                         #
################################################################################

proc format_line {n size} {
	set current_line [expr $size - $n]
	return [format {Line %s of %s} [commify $current_line] [commify $size]]
}

proc format_mtime {path} {
	set mtime [file mtime $path]
	return [clock format $mtime -format {%Y/%m/%d at %r %Z}]
}

proc format_size {path} {
	set size [file size $path]

	if {$size == 1} {
		return {1 byte}
	}

	if {$size >= 1073741824} {
		return [format {%.2f GB} [expr $size / 1073741824.0]]
	}

	if {$size >= 10485760} {
		return [format {%.1f MB} [expr $size / 1048576.0]]
	}

	if {$size > 1048576} {
		return [format {%.2f MB} [expr $size / 1048576.0]]
	}

	if {$size >= 10240} {
		return [format {%.1f KB} [expr $size / 1024.0]]
	}

	if {$size >= 1024} {
		return [format {%.2f KB} [expr $size / 1024.0]]
	}

	return "$size bytes"
}

proc commify {n} {
	regsub -all {\d(?=(\d{3})+($|\.))} $n {\0,} n
	return $n
}

################################################################################
# Main function                                                                #
################################################################################

proc main {} {
	make_window $::default_width $::default_height
	make_widgets $::log_directory
}

main