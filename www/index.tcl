ad_page_contract {

    @author Frank Bergmann frank.bergmann@project-open.com
    @creation-date 2012-05-10
    @cvs-id $Id$

} {

}

# ******************************************************
# Default & Security
# ******************************************************

set user_id [ad_maybe_redirect_for_registration]
set user_is_admin_p [im_is_user_site_wide_or_intranet_admin $user_id]
if {!$user_is_admin_p} {
    ad_return_complaint 1 "You have insufficient privileges to use this page"
    return
}

set title "Demo-Data"
set context [list [list "/intranet-dynfield/" "DynField"] [list "object-types" "Object Types"] $title]
set return_url [im_url_with_query]

# ******************************************************
# 
# ******************************************************

lappend action_list "Recalculate Day" "[export_vars -base "recalculate-day" {day}]" "Log hours for this day"

list::create \
    -name days_list \
    -multirow days_multirow \
    -key day \
    -actions $action_list \
    -no_data "No days pages" \
    -bulk_actions [list "Recalculate Day" recalculate-day "Recalculate Day"] \
    -bulk_action_export_vars { return_url } \
    -bulk_action_method GET \
    -elements {
	day {
	    label "Day" 
	    link_url_col details_url
	}
	timesheet_hours_logged {
	    label "TS Hours" 
	}
	employees_available {
	    label "Emps Avail" 
	}
    } \
    -orderby {
	page_url {orderby page_url}
	days_type {orderby days_type}
	default_p {orderby default_p}
    } \
    -filters {
	object_type {}
    }



set days_multirow_sql "
	select	day.day,
		(	select	round(sum(e.availability / 100.0))
			from	im_employees e
			where	e.employee_id in (select member_id from group_distinct_member_map where group_id = [im_employee_group_id])
		) as employees_available,
		(	select	sum(h.hours)
			from	im_hours h
			where	h.day::date = day.day
		) as timesheet_hours_logged
	from	im_day_enumerator('2012-01-01', '2012-05-06') day
	order by
		day.day DESC
"

db_multirow -extend {delete_url} days_multirow get_pages $days_multirow_sql {
    set delete_url [export_vars -base "days-del" { object_type page_url }]
}
