-- intranet-demo-data/sql/postgresql/users-skills.sql
--
-- Setup users with specific availabilities


--    624 | System             | Administrator        |          100
update im_employees	set availability = 100	where employee_id = 624;
--   8789 | Draco              | Draculevich          |	  	 100
update im_employees	set availability = 100	where employee_id = 8789;
--   8799 | Tracy              | Translationmanager   |          100
update im_employees	set availability = 100	where employee_id = 8799;
--   8811 | Angelique          | Picard               |	  	 100
update im_employees	set availability = 100	where employee_id = 8811;
--   8823 | David              | Developer            |          100
update im_employees	set availability = 100	where employee_id = 8823;
--   8828 | Daniel             | Damnfast             |	  	  100
update im_employees	set availability = 100	where employee_id = 8828;
--   8843 | Petra              | Projectmanager       |           60
update im_employees	set availability = 60	where employee_id = 8843;
--   8849 | Toni               | Tester               |          100
update im_employees	set availability = 100	where employee_id = 8849;
--   8858 | Laura              | Leadarchitect        |          100
update im_employees	set availability = 100	where employee_id = 8858;
--   8864 | Ben                | Bigboss              |           50
update im_employees	set availability = 50	where employee_id = 8864;
--   8869 | Andrew             | Accounting           |           30
update im_employees	set availability = 30	where employee_id = 8869;
--   8875 | Samuel             | Salesmanager         |           30
update im_employees	set availability = 30	where employee_id = 8875;
--   8881 | Sally              | Sales                |           50
update im_employees	set availability = 50	where employee_id = 8881;
--   8887 | Garry              | Groupmanager         |          100
update im_employees	set availability = 100	where employee_id = 8887;
--   8892 | Carlos             | Codificador          |          100
update im_employees	set availability = 100	where employee_id = 8892;
--   8898 | Bobby              | Bizconsult           |          100
update im_employees	set availability = 100	where employee_id = 8898;
--  10973 | Freddy             | Freelancer           |	  	  100
update im_employees	set availability = 100	where employee_id = 10973;
--  27484 | Harry              | Helpdesk             |          100
update im_employees	set availability = 100	where employee_id = 27484;
--   9063 | Ester              | Arenas               |
update im_employees	set availability = 100	where employee_id = 9063;


-- Rename Tracy Translationmanager
update persons set last_name = 'Troubleshoot' where person_id = 8799;

update im_employees set department_id = 12356 where employee_id = 8898;	-- Bobby Bizconsult member of "Business Analysis"




update persons set first_names = 'Consultant', last_name = 'Consultant' where person_id = 8987;
update users set username = 'cons' where user_id = 8987;
update parties set email = 'consultant@tigerpond.com' where party_id = 8987;

update persons set first_names = 'Project', last_name = 'Manager' where person_id = 8989;
update users set username = 'pm' where user_id = 8989;
update parties set email = 'pm@tigerpond.com' where party_id = 8989;

update persons set first_names = 'Administrator', last_name = 'Administrator' where person_id = 8991;
update users set username = 'admin' where user_id = 8991;
update parties set email = 'admin@tigerpond.com' where party_id = 8991;

update persons set first_names = 'Developer', last_name = 'Developer' where person_id = 8997;
update users set username = 'dev' where user_id = 8997;
update parties set email = 'dev@tigerpond.com' where party_id = 8997;

update persons set first_names = 'Database', last_name = 'Administrator' where person_id = 8999;
update users set username = 'dba' where user_id = 8999;
update parties set email = 'dba@tigerpond.com' where party_id = 8999;

update persons set first_names = 'Presales', last_name = 'Presales' where person_id = 9003;
update users set username = 'presales' where user_id = 9003;
update parties set email = 'presales@tigerpond.com' where party_id = 9003;

update persons set first_names = 'Tester', last_name = 'Tester' where person_id = 9005;
update users set username = 'tester' where user_id = 9005;
update parties set email = 'tester@tigerpond.com' where party_id = 9005;

update persons set first_names = 'Senior', last_name = 'Developer' where person_id = 9007;
update users set username = 'sendev' where user_id = 9007;
update parties set email = 'senior.developer@tigerpond.com' where party_id = 9007;

update persons set first_names = 'Junior', last_name = 'Developer' where person_id = 9013;
update users set username = 'jundev' where user_id = 9013;
update parties set email = 'junior.developer@tigerpond.com' where party_id = 9013;



-- Remove users from all previous groups (except for group -2 (registered users))
update membership_rels set member_state = 'deleted' 
where rel_id in (
	select	rel_id 
	from	acs_rels 
	where	object_id_two in (8987, 8989, 8991, 8997, 8999, 9003) and
		object_id_one > 0	    
);

-- Enable group membership in "Skill Profiles"
update membership_rels set member_state = 'approved' 
where rel_id in (
	select	rel_id 
	from	acs_rels 
	where	object_id_two in (8987, 8989, 8991, 8997, 8999, 9003) and
		object_id_one = (select group_id from groups where group_name = 'Skill Profile')
);


SELECT membership_rel__new((select group_id from groups where group_name = 'Skill Profile'), 8987);
SELECT membership_rel__new((select group_id from groups where group_name = 'Skill Profile'), 8989);
SELECT membership_rel__new((select group_id from groups where group_name = 'Skill Profile'), 8991);
SELECT membership_rel__new((select group_id from groups where group_name = 'Skill Profile'), 8997);
SELECT membership_rel__new((select group_id from groups where group_name = 'Skill Profile'), 8999);
SELECT membership_rel__new((select group_id from groups where group_name = 'Skill Profile'), 9003);
SELECT membership_rel__new((select group_id from groups where group_name = 'Skill Profile'), 9005);
SELECT membership_rel__new((select group_id from groups where group_name = 'Skill Profile'), 9007);
SELECT membership_rel__new((select group_id from groups where group_name = 'Skill Profile'), 9013);


--   9017 | Valery             | Waters
--   9021 | Audrey             | Lucas
--   9025 | Marcela            | Gray
--   9027 | Liliana Bernardita | Turner
--   9029 | Patricio           | Boehning
--   9033 | Ada                | Renta
