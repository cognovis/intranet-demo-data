# packages/intranet-demo-data/tcl/intranet-demo-data-procs.tcl
ad_library {

  Support procs for the intranet-demo-data package

  @author Frank Bergmann (frank.bergmann@project-open.com)
  @creation-date 2012-05-06

  @vss $Workfile: intranet-dynfield-procs.tcl $ $Revision$ $Date$
}



ad_proc im_demo_data_create_beaches {
    -day:required
} {
    The "Beach" are the projects for non-productive hours.
    These beaches are created per year.
    All users are assigned to the beaches, so that all users
    can log unproductive hours.
} {
    # -----------------------------------------------------
    # Check if there is a beach for day

    set beaches [db_list beach_count "
    	select	  project_id
	from	  im_projects main_p
	where	  main_p.parent_id is null and
		  main_p.start_date <= :day and
		  main_p.end_date >= :day and
		  main_p.company_id = [im_company_internal] and
		  lower(main_p.project_nr) like '%beach%'
    "]

    lappend beaches 0
#    ad_return_complaint 1 $beaches

    db_dml beach_open "
    	update im_projects
	set project_status_id = [im_project_status_open],
	    project_type_id = [im_project_type_other]
	where project_id in ([join $beaches ","])
    "

    db_1row info "
    	select	to_char(now(), 'YYYY') as year
	from	dual     
    "

    # Close all "beaches"
    set open_beaches [db_list open_beaches "
		select	project_id
		from	im_projects
		where	parent_id is null and
			project_status_id = [im_project_status_open] and
			(project_nr like '20%_beach' or project_nr like '20%_op') and
			project_nr not in (:year || '_beach', :year || '_op')
    "]
    foreach pid $open_beaches {
        ToDo: Remove this line once closing old beaches works
        db_dml close_beaches "
		update im_projects
		set	project_status_id = [im_project_status_closed]
		where	project_id = :pid
        "
    }



    # define the list of projects to create
    set beaches [list \
    	[list ""		"Beach $year"			"${year}_beach"			""				] \
    	[list "${year}_beach"	"Beach $year - Vacation"	"${year}_beach_vacation"	[im_profile_employees]		] \
    	[list "${year}_beach"	"Beach $year - Training"	"${year}_beach_training"	[im_profile_employees]		] \
    	[list ""		"Operations $year"		"${year}_op"			""				] \
    	[list "${year}_op"	"Operations $year - Marketing"	"${year}_op_marketing"		[im_profile_sales]		] \
    	[list "${year}_op"	"Operations $year - Sales"	"${year}_op_sales"		[im_profile_sales]		] \
    	[list "${year}_op"	"Operations $year - Other"	"${year}_op_other"		[im_profile_senior_managers] 	] \
    ]

    foreach tuple $beaches {
	set beach_parent [lindex $tuple 0]
	set beach_name [lindex $tuple 1]
	set beach_nr [lindex $tuple 2]
	set beach_group_id [lindex $tuple 3]
	set beach_parent_id [db_string beach_parent "select project_id from im_projects where project_nr = :beach_parent" -default ""]

	# Create new beach for the current year
	set beach_parent_null_sql "parent_id = :beach_parent_id"
	if {"" == $beach_parent_id} { set beach_parent_null_sql "parent_id is null" }

	set main_beach_id [db_string beach_exists "
		select	project_id
		from	im_projects
		where	project_nr = :beach_nr and
			$beach_parent_null_sql
	" -default ""]

	if {"" == $main_beach_id} {
	    set main_beach_id [project::new \
				   -project_name $beach_name \
				   -project_nr $beach_nr \
				   -project_path $beach_nr \
				   -company_id [im_company_internal] \
				   -parent_id $beach_parent_id \
				   -project_type_id [im_project_type_other] \
				   -project_status_id [im_project_status_open] \
	    ]
	}

	# Update some addional variables
	db_dml main_beach "
		update im_projects set
			project_lead_id = (select min(user_id) from users where user_id > 0),
			start_date = '${year}-01-01'::date,
			end_date = '${year}-12-31'::date
		where project_id = :main_beach_id
	 "

	# Make all employees members of the beach
	im_biz_object_add_role $beach_group_id $main_beach_id [im_biz_object_role_full_member]
    }

}




ad_proc im_demo_data_project_work_hours {
    -project_id:required
} {
    Returns the accumulated estimated_hours of a project.
} {
    return [util_memoize [list im_demo_data_project_work_hours_helper -project_id $project_id]]
}

ad_proc im_demo_data_project_work_hours_helper {
    -project_id:required
} {
    Returns the accumulated estimated_hours of a project.
} {
    set work_hours_sql "
	select	sum(planned_units * uom_factor) from (
	select	t.planned_units,
		CASE WHEN t.uom_id = 321 THEN 8.0 ELSE 1.0 END as uom_factor
	from	im_projects main_p,
		im_projects sub_p,
		im_timesheet_tasks t
	where	main_p.project_id = :project_id and
		sub_p.project_id = t.task_id and
		sub_p.tree_sortkey between main_p.tree_sortkey and tree_right(main_p.tree_sortkey)
	) t
    "

    return [db_string estimated_hours $work_hours_sql]
}


ad_proc im_demo_data_company_load {
    -start_date:required
    -end_date:required
} {
    Calculates the average work load for the entire company in the 
    specified date interval. These values are used later to calculate
    where to place new projects.
} {
    # -----------------------------------------------------
    # Check the average work load for the next days

    set workload_sql "
select	sum(estimated_days / project_duration_days) as project_work,
	day
from	(
    	select	day.day,
		main_p.project_id,
		main_p.project_nr,
		main_p.project_name,
		abs(coalesce(main_p.end_date::date - main_p.start_date::date, 0.0)) + 0.0001 as project_duration_days,
		(select	coalesce(sum(planned_units * uom_factor), 0.0) / 8.0 from (
			select	t.planned_units,
				CASE WHEN t.uom_id = 321 THEN 8.0 ELSE 1.0 END as uom_factor
			from	im_projects sub_p,
				im_timesheet_tasks t
			where	sub_p.project_id = t.task_id and
				sub_p.tree_sortkey between main_p.tree_sortkey and tree_right(main_p.tree_sortkey)
		) t) as estimated_days
	from	im_projects main_p,
		im_day_enumerator(:start_date, :end_date) day
	where	main_p.parent_id is null and
		main_p.project_status_id in (select * from im_sub_categories([im_project_status_open])) and
		main_p.start_date <= day.day and
		main_p.end_date > main_p.start_date
	) open_tasks
group by day
order by day
    "

    return "
[im_ad_hoc_query $workload_sql]
    "

#    return [join [db_list_of_lists workload $workload_sql] "\n"]
}


ad_proc im_demo_data_create_project {
    {-template_id ""}
    {-new_start_date ""}
    {-company_id "" }
    {-project_name "" }
    {-project_nr "" }
} {
    Checks for the average work load in the upcoming days
    and creates randomly projects to keep the work load
    at a certain percentage
} {
    # -----------------------------------------------------
    # Select a random active customer
    if {"" == $company_id} {
	set customer_list [db_list customer_list "
		select	c.company_id
		from	im_companies c
		where	c.company_status_id = [im_company_status_active] and
			c.company_type_id in (select * from im_sub_categories([im_company_type_customer]))
	"]
	set company_id [util::random_list_element $customer_list]
    }

    # Select a random template if not specified
    if {"" == $template_id} {
	set template_list [db_list customer_list "
		select	p.project_id
		from	im_projects p
		where	p.parent_id is null and
			(p.template_p = 't' OR p.project_name like '%Template%') and
			p.project_status_id not in (select * from im_sub_categories([im_project_status_closed])) and
			p.project_type_id not in ([im_project_type_task], [im_project_type_ticket])
	"]
	set template_id [util::random_list_element $template_list]
    }

    if {"" == $project_name} {
	set template_project_name [db_string template_name "select project_name from im_projects where project_id = :template_id" -default ""]
	if {"" == $template_project_name} { ad_return_complaint 1 "im_demo_data_create_projects: invalid template #$template_id" }
	if {[regexp {^(.*)Template(.*)$} $template_project_name match tail end]} {
	    set template_project_name [string trim [concat [string trim $tail] " " [string trim $end]]]
	}
	set customer_name [db_string customer_name "select company_name from im_companies where company_id = :company_id" -default ""]
	if {"" == $customer_name} { ad_return_complaint 1 "im_demo_data_create_projects: invalid customer #$company_id" }

	set project_name [concat $customer_name $template_project_name]
    }

    if {"" == $project_nr} {
        set project_nr [im_next_project_nr]
    }

    if {"" == $new_start_date} {
       set new_start_date_list [db_list new_start_date_list "select day from im_day_enumerator(now()::date - 30, now()::date + 180) day"]
       set new_start_date [util::random_list_element $new_start_date_list]
    }

    set parent_project_id ""
    set clone_postfix "Clone"

    set cloned_project_id [im_project_clone \
                   -clone_costs_p 0 \
                   -clone_files_p 0 \
                   -clone_subprojects_p 1 \
                   -clone_forum_topics_p 1 \
                   -clone_members_p 1 \
                   -clone_timesheet_tasks_p 1 \
                   -clone_target_languages_p 0 \
                   -company_id $company_id \
                   $template_id \
                   $project_name \
                   $project_nr \
                   $clone_postfix \
    ]

    # Update the main project's name and nr
    db_dml update_cloned_project "
	update im_projects set
		project_name = :project_name,
		project_nr = :project_nr,
		project_path = :project_nr,
		template_p = 'f'
	where project_id = :cloned_project_id      
    "

    # Update the start- and end_date of the project structure
    set move_days [db_string move_days "select :new_start_date::date - p.start_date::date from im_projects p where project_id = :cloned_project_id"]
    db_dml move_cloned_project "
	    update im_projects set
	    	project_status_id = [im_project_status_open],
		start_date = start_date + :move_days * '1 day'::interval,
		end_date = end_date + :move_days * '1 day'::interval
	    where
		project_id in (
			select	sub_p.project_id
			from	im_projects sub_p,
				im_projects main_p
			where	main_p.project_id = :cloned_project_id and
				sub_p.tree_sortkey between main_p.tree_sortkey and tree_right(main_p.tree_sortkey)
		)
    "  

    return $cloned_project_id
}



ad_proc im_demo_data_staff_project {
    -project_id:required
} {
    Assigns the project tasks to "suitable" employees.
} {
    # -----------------------------------------------------
    # Get the list of profiles used in the project
    set profile_sql "
    	select	sum(coalesce(bom.percentage, 100.0) * t.planned_units) as planned_units,
		r.object_id_two as profile_id,
		r.object_id_one as task_id
	from	im_projects main_p,
		im_projects p
		LEFT OUTER JOIN im_timesheet_tasks t ON (p.project_id = t.task_id)
		LEFT OUTER JOIN acs_rels r ON (p.project_id = r.object_id_one)
		LEFT OUTER JOIN im_biz_object_members bom ON (r.rel_id = bom.rel_id)
	where	main_p.project_id = 32605 and
		p.tree_sortkey between main_p.tree_sortkey and tree_right(main_p.tree_sortkey) and
		r.object_id_two not in (select min(user_id) from users where user_id > 0)
	group by
		r.object_id_two, r.object_id_one
	order by
		task_id, profile_id
    "
    db_foreach emps $profile_sql {
	set profile_hash($profile_id) $availability
    }


    # -----------------------------------------------------
    # Get the list of employees together with their availability
    set employee_sql "
    	select	  e.employee_id,
		  e.availability
	from	  im_employees e,
		  cc_users u
	where	  u.user_id = e.employee_id and
		  e.employee_id in (select member_id from group_distinct_member_map where group_id = [im_employee_group_id])
   "
    db_foreach emps $employee_sql {
	set employee_hash($employee_id) $availability
    }

    # -----------------------------------------------------
    # Get the current assignments of the user to projects and tasks
    set direct_assig_sql "
    	select	u.user_id,
		p.project_id,
		bom.percentage
	from	im_projects p,
		acs_rels r,
		im_biz_object_members bom,
		users u
	where	r.rel_id = bom.rel_id and
		r.object_id_one = p.project_id and
		r.object_id_two in (
			select u.user_id from dual union 
			select group_id from group_element_index gei, membership_rels mr where gei.rel_id = mr.rel_id and gei.element_id = u.user_id
		) and
		bom.percentage is not null
    "
    db_foreach direct_assig $direct_assig_sql {
	set key "$user_id-$project_id"
	set project_direct_assig_hash($key) $percentage

	set direct_assig_sum 0
	if {[info exists direct_assig_hash($user_id)]} { set direct_assig_sum $direct_assig_hash($user_id) }
	set direct_assig_sum [expr $direct_assig_sum + $percentage]
	set direct_assig_hash($user_id) $direct_assig_sum
    }

    ad_return_complaint 1 "<pre>emp: [array get employee_hash]\nts: [array get ts_hash]\ndirect_assig: [array get direct_assig_hash]\n</pre>"

}

ad_proc im_demo_data_log_timesheet_hours {
    {-day ""}
} {
    Checks demo-data for a single day:
    <ul>
    <li>Check that all employees have logged their hours
        and advance their projects accordingly.
    <li>
    </ul>
} {
    if {"" == $day} {
	set day [db_string default_day "
		select	max(day)::date + 1
		from	im_hours
	" -default ""]
	if {"" == $day} { set day [db_string now "'select now()::date - 365 from dual"] }
    }

    # Default user for logging data
    set admin_user_id [db_string admin_user "select min(user_id) from users where user_id > 0" -default 0]

    # Get the current im_audits.audit_id, so that we can 
    # move all new audit records to the specified day
    set start_audit_tz [db_string org_audit_tz "select now() from dual" -default 0]

    # -----------------------------------------------------
    # Get the list of employees together with their availability
    set employee_sql "
    	select	  e.employee_id,
		  coalesce(e.availability, 100.0) as availability
	from	  im_employees e,
		  cc_users u
	where	  u.user_id = e.employee_id and
		  e.employee_id in (select member_id from group_distinct_member_map where group_id = [im_employee_group_id])
   "
    db_foreach emps $employee_sql {
	set employee_hash($employee_id) $availability
    }

    # -----------------------------------------------------
    # Get the currently logged hours per employee
    set ts_sql "
	select	h.user_id,
		sum(h.hours) as hours
	from	im_hours h
	where	h.day = :day
	group by h.user_id
    "
    db_foreach ts_hours $ts_sql {
    	set ts_hash($user_id) $hours
    }

    # -----------------------------------------------------
    # Get the current assignments of the user to projects and tasks
    set direct_assig_sql "
    	select	u.user_id,
		p.project_id,
		bom.percentage
	from	im_projects p,
		im_timesheet_tasks t,
		acs_rels r,
		im_biz_object_members bom,
		users u
	where	p.project_id = t.task_id and
		r.rel_id = bom.rel_id and
		r.object_id_one = p.project_id and
		r.object_id_two in (
			select u.user_id from dual union 
			select group_id from group_element_index gei, membership_rels mr where gei.rel_id = mr.rel_id and gei.element_id = u.user_id
		) and
		bom.percentage is not null and
		coalesce(p.percent_completed, 0.0) < 100.0
    "
    db_foreach direct_assig $direct_assig_sql {
	set key "$user_id-$project_id"
	set project_direct_assig_hash($key) $percentage

	set direct_assig_sum 0
	if {[info exists direct_assig_hash($user_id)]} { set direct_assig_sum $direct_assig_hash($user_id) }
	set direct_assig_sum [expr $direct_assig_sum + $percentage]
	set direct_assig_hash($user_id) $direct_assig_sum
    }


    # -----------------------------------------------------
    # All available tasks to work on
    set open_tasks_sql "
	select	t.task_id,
		coalesce(p.percent_completed, 0) as percent_completed
	from	im_projects p,
		im_timesheet_tasks t
	where	p.project_id = t.task_id and
		coalesce(p.percent_completed, 0) < 100.0 and
		p.project_status_id in (select * from im_sub_categories([im_project_status_open])) and
		p.end_date >= :day
    "
    db_foreach open_tasks $open_tasks_sql {
	set open_tasks_hash($task_id) $percent_completed
    }


    foreach uid [array names employee_hash] {
	ns_log Notice "im_demo_data_log_timesheet_hours: Logging hours for user_id=$uid"
	
	# Clean the array from last user
	array unset uid_hash
	
	# Check if there are direct assignments
	set percent_available $employee_hash($uid)
	set hours_today [expr round($percent_available * 8.0 * ((1.5 + rand()) / 2.0)) / 100.0]

	# Check if there are direct assignments for this user
	foreach tuple [array names project_direct_assig_hash] {
	    regexp {([^\-])\-([^\-])} $tuple match tuple_uid tuple_pid
	    if {$uid == $tuple_uid} {
	        set uid_hash($tuple_pid) $project_direct_assig_hash($tuple)
	    }
	}

	# Pick two random tasks where something is to do...
	if {"" == [array get uid_hash]} {
	    set task_list [array names open_tasks_hash]
	    set task_1 [util::random_list_element $task_list]
	    set task_2 [util::random_list_element $task_list]
	    set uid_hash($task_1) 50.0
	    set uid_hash($task_2) 50.0
	}

	# Normalize the uid_hash
	set percent_assigned_total 0
	foreach tid [array names uid_hash] {
	    set percent_assigned_total [expr $percent_assigned_total + $uid_hash($tid)]
	}

	ns_log Notice "im_demo_data_log_timesheet_hours: user=$uid will log $hours_today hours on tasks [array get uid_hash]"

	# Log hours on the specified tasks
	array set modified_projects_hash {}
	foreach tid [array names uid_hash] {

	    set perc_assig $uid_hash($tid)
	    set hours [expr $hours_today * $perc_assig / 100.0]

	    # Calculate the advance of the task
	    db_1row task_info "
	    	select	coalesce(t.planned_units, 8.0) as task_planned_units,
			coalesce(p.percent_completed, 0.0) as task_percent_completed
		from	im_projects p,
			im_timesheet_tasks t
		where	p.project_id = t.task_id and
			t.task_id = :tid
	    "

	    # Efficiency of work greatly varies between 0.5 and 1.5 ...
	    set rand_factor [expr (0.5 + rand()) / 1.0 ]
	    set percent_done [expr 100.0 * $hours / $task_planned_units * $rand_factor]
	    set new_percent_completed [expr $task_percent_completed + $percent_done]
	    if {$new_percent_completed > 100.0} { set new_percent_completed 100.0 }
	    ns_log Notice "im_demo_data_log_timesheet_hours: task(tid=$tid, est=$task_planned_units, compl=$task_percent_completed) gets $percent_done percent completed today"

	    db_dml hours_insert "
		insert into im_hours (user_id, project_id, day, hours) 
		values (:uid, :tid, :day, :hours)
	    "

	    db_dml task_update "
		update im_projects
		set percent_completed = :new_percent_completed
		where project_id = :tid
	    "

	    # Remember the modified projects
	    set main_project_id [im_project_main_project $tid]
	    set modified_projects_hash($tid) $tid
	    set modified_projects_hash($main_project_id) $main_project_id
	}
    }


    # Fake the creation_date of cost objects and audit information
    # Therefore store the information about the last objects
    set prev_cost_id [db_string prev_cost_id "select max(cost_id) from im_costs"]
    set prev_audit_id [db_string prev_audit "select last_value from im_audit_seq"]

    # Update cache information of projects and audit
    foreach pid [array names modified_projects_hash] {
    
	# Update the cost caches
	im_timesheet_update_timesheet_cache -project_id $pid

	# Calculate the %completed of the project
	im_timesheet_project_advance $pid

	# Re-calculate the cost cache
	im_cost_update_project_cost_cache $pid
	
	# Write an audit record
	# im_audit -object_id $tid -user_id $admin_user_id -action "after_update" -comment "im_demo_data_log_timesheet_hours: Simulating hour logging"
    }

    # Patch costs objects
    db_dml patch_costs "update im_costs set effective_date = :day where cost_id > :prev_cost_id"
    db_dml patch_cost_objects "update acs_objects set creation_date = :day where object_type = 'im_cost' and object_id > :prev_cost_id"

    # Move all audit records back to the specified day
    set end_audit_tz [db_string end_audit_tz "select now() from dual" -default 0]
    db_dml shift_audits "update im_audits set audit_date = :day where audit_date between :start_audit_tz and :end_audit_tz"
    db_dml shift_project_audits "update im_projects_audit set last_modified = :day where last_modified between :start_audit_tz and :end_audit_tz"

    ad_return_complaint 1 "<pre>emp: [array get employee_hash]\nts: [array get ts_hash]\ndirect_assig: [array get direct_assig_hash]\ntasks: [array get open_tasks_hash]</pre>"

}
