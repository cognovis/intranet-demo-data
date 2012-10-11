# packages/intranet-demo-data/tcl/intranet-demo-data-risk-procs.tcl
ad_library {

    Risk support
    @author Frank Bergmann (frank.bergmann@project-open.com)
    @creation-date 2012-10-06
    
    @vss $Workfile: intranet-dynfield-procs.tcl $ $Revision$ $Date$
}


ad_proc im_demo_data_risk_create {
    { -day ""}
    -project_id:required
} {
    Add a few random risks to a project
} {
    if {"" == $day} { set day "2012-01-01" }

    # Assume and average cost per hour of EUR/USD 50/h
    set project_hours [im_demo_data_timesheet_work_hours -project_id $project_id]
    set project_cost [expr round($project_hours * 50.0)]

    db_0or1row project_info "
	select	project_lead_id,
		project_budget
	from	im_projects
	where	project_id = :project_id
    "
    if {"" == $project_lead_id} { set project_lead_id [ad_get_user_id] }
    if {"" == $project_budget} {
	set project_budget $project_cost
	# Update the projct's budget, because otherwise the
	# risk portlet can't show the risk matrix
	db_dml update_project "update im_projects set project_budget = :project_cost where project_id = :project_id"
    }

    set risks {
	{
	    "Loss to project of key staff" 
	    "low" "high" 
	    "Unable to complete key tasks" 
	    "Emphasise importance of project within organization."
	    "Reports of absence, or diversion of staff to other work."
	    "Identify alternative resources in case of unexpected absence."
	} {
	    "Significant changes in user requirements" 
	    "low" "high" 
	    "Time-quality-cost"
	    "Ensure that the user requirements are fully agreed before specification."
	    "Request for changes to agreed specification."
	    "Discuss impact of change on schedules or design, and agree if change to specification will proceed. Implement project change, if agreed."
	} {
	    "Major changes to organization structure"
	    "low" "high" 
	    "Changes to system, processes, training, rollout"
	    "None"
	    "Information from senior staff."
	    "Make sure management are aware of need for user input from people with different responsibilities"
	} {
	    "Volume of change requests following testing extending work on each phase"
	    "high" "high" 
	    "Delays"
	    "Agree specification. Agree priorities. Reasonable\
 consultation on format"
	    "Swamped with changes. Delay in signing off items"
	    "Managerial decision on importance, technically feasibility and observance of time constraints"
	} {
	    "Changes in priorities of senior management"
	    "med" "high" 
	    "Removal of resource, lack of commitment, change in strategy or closure of project"
	    "Make sure that senior management are aware of the project, its relative importance, and its progress"
	    "Announcements in University publications, meetings etc."
	    "Inform senior management of the knock on effects of their decisions."
	} {
	    "Lack of organizational or departmental buy-in"
	    "high" "high" 
	    "Failure to achieve business benefits. Ineffective work practices. More fragmented processes. Poor Communication"
	    "Ensure User Requirements are properly assessed. Executive leadership and ongoing involvement. Communications and planning focus. Appoint Comms Manager"
	    "Staff Survey, Benefits realisation monitoring"
	    "Review deliverables"
	} {
	    "Lack of commitment or ability to change current business processes"
	    "high" "medium"
	    "Failure to achieve business benefits. Extended duration. Scope creep to copy today's processes."
	    "Requires additional business process analyst resource."
	    "Lack of commitment to reviewing and challenging existing processes early in the project."
	    "Attempt to engage users depts. Involve senior management."
	} {
	    "GED adherence to costs"
	    "high"
	    "low"
	    "Careful analysis of contract (task description)"
	} {
		"Algoritmic close-down threshold overrun"
		"med"
		"low"
		"GED have accepted risk within development budget. Initial testing indicated no start-up issues."
	} {
		"Problems with algorithm integration"
		"low"
		"low"
		"Some development time for engineers budgeted"
	} {
		"Dust on container housing"
		"high"
		"low"
		"1) Possible new housing design, 2) velocity filters might be removed, 3) Pre-amplifier evaluated as probably workable."
	} {
		"Object detection issues"
		"med"
		"high"
		"Real issue but expect to be fixed soon - sent for evaluation"
	} {
		"Alignment tolerance"
		"low"
		"low"
		"1) Dynamic alignment, 2) Re-design housing"
	} {
		"Find velocity sensor that offers the same performance as the lab sample"
		"high"
		"low"
		"This will be mitigated by focusing the GED development on delivering a first sunsite antenna."
	} {
		"Dynamic detection algorithm"
		"med"
		"low"
		"Re-used from previous project - might need modification"
	} {
		"DRP - Weather detection"
		"low"
		"low"
		"Extended weather testing - Integration tests suggest not an issue"
	} {
		"First pass sunsite front end design."
		"high"
		"low"
		"Impact on delay and business case."
	} {
		"Unexpected radio interference from preliminary testing"
		"med"
		"low"
		"Mitigation underway at sunsite design stage - delayed until test results of sunsite known."
	} {
		"Velocity sensor will require larger housing"
		"low"
		"low"
		"Most of the financial risk is accepted but the delay will be on project preliminary testing"
	} {
		"General exchange rate risk"
		"high"
		"low"
		"Works cost impact. May mean project is no longer viable."
	} {
		"Issue with lead time of key providers"
		"low"
		"high"
		"Problem is that we will program with V4.0 and there is risk of compiler differences when moving to V4.1"
	} {
		"MTBF values wrong from preliminary testing"
		"low"
		"med"
		"Switch to more endurable devices"
	} {
		"Operating labour requirements above plan"
		"high"
		"med"
		"More tests needed in order to determine actual requirements"
	} {
		"Customer priority change"
		"med"
		"med"
		""
	} {
		"Regression testing"
		"low"
		"high"
		"Regression testing and risk now included"
	} {
		"Parallel task processing - deadlocks"
		"high"
		"med"
		"Zone asymetry of processes reduced - need more realistic testing scenarios"
	} {
		"Unable to reduce engineering works costs"
		"med"
		"high"
		"Engineering cost currently within expectation - always a risk due to Euro rate"
	} {
		"Velocity detection performance may degrade due to small adjustments"
		"low"
		"high"
		"Requires waiting for next available testing window"
	}
    }

    set max_risk_count [expr 2 + int(rand() * 5.0)]
    for {set i 0} {$i < $max_risk_count} {incr i} {

	# Choose a random risk
	set risk [util::random_list_element $risks]
	ns_log Notice "im_demo_data_risk_create: risk=$risk"

	# Extract risk information
	set risk_name [lindex $risk 0]
	if {"" == $risk_name} { continue }
	set risk_probability_level [lindex $risk 1]
	set risk_impact_level [lindex $risk 2]
	set risk_effect_on_project [lindex $risk 3]
	set risk_mitigation_actions [lindex $risk 4]
	set risk_triggers [lindex $risk 5]
	set risk_actions [lindex $risk 6]

	switch $risk_probability_level {
	    low { set risk_probability [expr rand() * 15.0] }
	    med { set risk_probability [expr 15.0 + rand() * 30.0] }
	    high { set risk_probability [expr 45.0 + rand() * 55.0] }
	    default { set risk_probability [expr rand() * 50.0] }
	}
	set risk_probability [expr round($risk_probability / 5.0) * 2.0]

	switch $risk_impact_level {
	    low { set risk_impact [expr 100 + $project_cost * (rand() * 0.10)] }
	    med { set risk_impact [expr $project_cost * (0.10 + rand() * 0.10)] }
	    high { set risk_impact [expr $project_cost * (0.20 + rand() * 0.20)] }
	    default { set risk_impact [expr $project_cost * (rand() * 0.3)] }
	}
	set risk_impact [expr round($risk_impact / 100.0) * 100]

	set risk_status_id 75000
	set risk_type_id 75100

	set risk_id [db_string exists_p "select risk_id from im_risks where risk_project_id = :project_id and lower(trim(risk_name)) = lower(trim(:risk_name))" -default ""]
	
	if {"" == $risk_id} {
	    set risk_id [db_string new_risk "select im_risk__new (
		-- Default 6 parameters that go into the acs_objects table
		null,			-- risk_id  default null
		'im_risk',		-- object_type default im_risk
		:day,			-- creation_date default now()
		:project_lead_id,		-- creation_user default null
		'0.0.0.0',		-- creation_ip default null
		null,			-- context_id default null

		-- Specific parameters with data to go into the im_risks table
		:project_id,	       	-- project container
		:risk_status_id,	-- active or inactive or for WF stages
		:risk_type_id,		-- user defined type of risk. Determines WF.
		:risk_name		-- Unique name of risk per project
	    )"]
	}

	db_dml update_risk "
		update im_risks set
			risk_probability_percent = :risk_probability,
			risk_impact = :risk_impact
		where risk_id = :risk_id
	"
    }
}
