program TDBxTest;

{$IFDEF CONSOLE_TESTRUNNER}
{$APPTYPE CONSOLE}
{$ENDIF}

uses
  DUnitTestRunner,
  DBx in 'DBx.pas',
  DBxTest in 'DBxTest.pas';

{$R *.RES}

begin

  DUnitTestRunner.RunRegisteredTests;

end.
