use [SELECT YOUR TEST DATABASE]
go


/*
ATTENTION! This script is provided as "AS IS" and with no warranty.
Please see LICENSE file.
*/

drop proc if exists test.RunAll;
drop proc if exists test.Run;

drop table if exists test.Actual;
drop table if exists test.Expected;

drop schema test;
