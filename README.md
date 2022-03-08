Simple test framework for TSQL tests with no additional assemblies, logins etc.

1. Use install.sql
2. Run example.sql or your own tests

**usage**
test.Run 'Test_YOUR_PROC_NAME';
test.RunAll;

Do not run your tests without "Run" or "RunAll"
