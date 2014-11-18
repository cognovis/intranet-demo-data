-- upgrade-4.1.0.0.0-4.1.0.0.1.sql
SELECT acs_log__debug('/packages/intranet-demo-data/sql/postgresql/upgrade/upgrade-4.1.0.0.0-4.1.0.0.1.sql','');

SELECT im_component_plugin__new (
       null, 'im_component_plugin', now(), null, null, null, 
       'ITSM Demo Instructions', 'intranet-demo-data', 'left', '/intranet/index', 
       null, 0, 'im_demo_data_poitsm_blurb_component'
);


SELECT acs_permission__grant_permission(
	(select plugin_id from im_component_plugins where plugin_name = 'ITSM Demo Instructions'),
	(select group_id from groups where group_name='Employees'), 
	'read'
);

