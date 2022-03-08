use [SELECT YOUR TEST DATABASE]
go


/*
ATTENTION! This script is provided as "AS IS" and with no warranty.
Please see LICENSE file.
*/


--
-- schema
--
create schema test authorization dbo;
go


--
-- test.Run
-- 
create proc test.Run
(
    @TestName nvarchar(200)
)
as
begin
set nocount on;

-- var
declare @msg        nvarchar(max);
declare @query      nvarchar(max);
declare @columns    nvarchar(max);
declare @result     int;

-- check test procedure object
if (object_id(@TestName, N'P') is null)
begin
    set @msg = concat(@TestName, N' doesn''t exist');
    print @msg;
    return 10001; -- Some error code
end

--
begin tran
begin try
    -- cleanup
    drop table if exists test.Expected;
    drop table if exists test.Actual;

    -- run
    set @query = concat('exec ', @TestName);
    exec sp_executesql @query;

    -- check
    if (object_id('test.Expected', N'U') is null) raiserror('Table "test.Expected" not finded', 16, 1);
    if (object_id('test.Actual'  , N'U') is null) raiserror('Table "test.Actual" not finded', 16, 1);

    -- not passed
    if  exists
        (
            select s.*, row_number() over (partition by [##JS] order by (select null)) as [##N]
            from (select t.*, (select t.* for json path) as [##JS] from test.Actual t) s
            except
            select s.*, row_number() over (partition by [##JS] order by (select null)) as [##N]
            from (select t.*, (select t.* for json path) as [##JS] from test.Expected t) s
        )
        or exists
        (
            select s.*, row_number() over (partition by [##JS] order by (select null)) as [##N]
            from (select t.*, (select t.* for json path) as [##JS] from test.Expected t) s
            except
            select s.*, row_number() over (partition by [##JS] order by (select null)) as [##N]
            from (select t.*, (select t.* for json path) as [##JS] from test.Actual t) s
        )
    begin
    
        -- find column names
        set @columns = stuff(
            (
                select ', ' + c.name
                from sys.all_columns c
                join sys.objects o on o.object_id = c.object_id
                join sys.schemas s on s.schema_id = o.schema_id
                where concat(s.name, '.', o.name) = 'test.Expected'
                order by c.column_id
                for xml path('')
            ), 1, 2, '');

        
        --
        set @query = concat('select ''', @TestName, ''' as [#Test], ''Actual'' as [#Source], * from
(
    select row_number() over (order by ', @columns, ') [#Row], *
    from test.Actual
    except
    select row_number() over (order by ', @columns, ') [#Row], *
    from test.Expected
) s
union all
select ''', @TestName, ''' as [#Test], ''Expected'' as [#Source], * from
(
    select row_number() over (order by ', @columns, ') [#Row], *
    from test.Expected
    except
    select row_number() over (order by ', @columns, ') [#Row], *
    from test.Actual
) s
order by [#Source], [#Row], ', @columns);
        exec sp_executesql @query;

        set @result = 1;
        set @msg = concat('"', @TestName, N'" not passed');
        print @msg;
    end
    -- passed
    else 
    begin
        set @result = 0;
        set @msg = concat('"', @TestName, N'" passed');
        print @msg;
    end

    if @@trancount > 0
        rollback;
end try
begin catch
    set @msg = concat(N'Exception in "', @TestName, '": ', error_message());
    print @msg;

    if @@trancount > 0
        rollback;

    return 10002; -- Some error code
end catch

return @result;
end -- sp
go


--
-- RunAll
--
create proc test.RunAll
as
begin
set nocount on;
drop table if exists #results;
create table #results (TestName nvarchar(200), Result int null);

-- var
declare @query nvarchar(200);


-- define test objects
declare QueryCursor cursor for
select concat('declare @r int; exec @r = test.Run ', ObjectName, '; insert into #results values (', ObjectName, ', @r);')
from
(
    select concat('''', s.name, '.', o.name, '''') as ObjectName
    from sys.objects o 
    join sys.schemas s on s.schema_id = o.schema_id
    where o.name like 'Test_%'
) s
order by ObjectName;


-- run
open QueryCursor
fetch next from QueryCursor into @query;
while @@fetch_status = 0
begin
	exec sp_executesql @query;
	fetch next from QueryCursor into @query;
end
close QueryCursor;
deallocate QueryCursor;


-- select results
declare @StatusSuccess   int = (select count(*) from #results where Result = 0);
declare @StatusFailure   int = (select count(*) from #results where Result = 1);
declare @StatusException int = (select count(*) from #results where Result > 10000);
declare @TestCount       int = (select count(*) from #results);

print concat(char(10), 'Success:   ', @StatusSuccess, '/', @TestCount);
if (@StatusFailure   > 0) print concat('Failure:   ', @StatusFailure,   '/', @TestCount);
if (@StatusException > 0) print concat('Exception: ', @StatusException, '/', @TestCount);


end; -- sp
go
