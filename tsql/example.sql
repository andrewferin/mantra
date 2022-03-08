use [SELECT YOUR TEST DATABASE]
go


/*
ATTENTION! This script is provided as "AS IS" and with no warranty.
Please see LICENSE file.
*/


--
create or alter proc dbo.Test_SomeTestCase
as
begin
set nocount on;

drop table if exists test.Actual;
drop table if exists test.Expected;

-- actual table
select *
into test.Actual
from
(
    values
        (3   , 1),
        (3   , 1),
        (null, 1)
) as R (Id, Val);

-- expected table
select *
into test.Expected
from
(
    values
        (3   , 1),
        (null, 1),
        (null, 1)
) as R (Id, Val);

end -- sp
go


test.Run 'dbo.Test_SomeTestCase';
