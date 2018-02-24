unit DBxTest;

interface

uses
  TestFramework, system.sysutils, Firedac.stan.Def, Firedac.comp.UI, Firedac.DApt,
  strutils, types, DBx, Firedac.stan.Option, Firedac.comp.dataset, Data.DB,
  Firedac.comp.client, faker, system.IOUtils;

type

  TestTDBx = class(TTestCase)
  private const
    database_name = 'tdbx';

    procedure connectMysql(aRunTests: Boolean = false);
    procedure connectSQLite3(aRunTests: Boolean = false);
    procedure connectPostGres(aRunTests: Boolean = false);

    function sqlite_db(dbName: string = ''): string;
    function genBackupFileName(aFileName: string): string;

    procedure createDatabase(aDatabaseName: string);
    procedure dropDatabase(aDatabaseName: string);
    procedure backupDatabase(aDatabaseName: string; aFileDestination: string = '');

    procedure CreateAndExistsTable;
    procedure dropTable;
    procedure renameTable;
    procedure columnExists;

    function selectCount(aTableName: string): Integer;
    function insert(aTableName, aColumnName: string): Integer;

    procedure selectTest;
    procedure insertTest;
    procedure updateTest;
    procedure deleteTest;

    procedure dbParams(driver, server, port, username, password, database, timeout: string);
    procedure connect(driver, server, port, username, password, database, timeout: string; aRunTests: Boolean = false);

  published

    // Database test connection
    procedure Test_Kill_Connection;
    procedure Test_Connect_To_MySQL;
    procedure Test_Connect_To_Postgres;
    procedure Test_Connect_To_SQLite3;
    procedure Test_Prevent_Connect_To_Invalid_Drive;

    // database
    procedure Test_Create_Database_And_Check_If_Exists_In_Mysql;
    procedure Test_Create_Database_And_Check_If_Exists_In_Postgres;
    procedure Test_Create_Database_And_Check_If_Exists_In_SQLite3;

    procedure Test_Drop_Database_In_Mysql;
    procedure Test_Drop_Database_In_Postgres;
    procedure Test_Drop_Database_In_SQLite3;

    procedure Test_Backup_Database_In_Mysql;
    procedure Test_Backup_Database_In_Postgres;
    procedure Test_Backup_Database_In_SQLite3;

    // tables
    procedure Test_Create_Table_And_Check_If_Exists_In_Mysql;
    procedure Test_Create_Table_And_Check_If_Exists_In_Postgres;
    procedure Test_Create_Table_And_Check_If_Exists_In_SQLite3;

    procedure Test_Rename_Table_In_Mysql;
    procedure Test_Rename_Table_In_Postgres;
    procedure Test_Rename_Table_In_SQLite3;

    procedure TestDrop_Table_In_Mysql;
    procedure TestDrop_Table_In_Postgres;
    procedure TestDrop_Table_In_SQLite3;

    // colums
    procedure Test_Column_Exists_In_Mysql;
    procedure Test_Column_Exists_In_Postgres;
    procedure Test_Column_Exists_In_SQLite3;

    // general puporse SQL
    procedure Test_Select_In_Mysql;
    procedure Test_Select_In_Postgres;
    procedure Test_Select_In_SQLite3;

    procedure Test_Insert_In_Mysql;
    procedure Test_Insert_In_Postgres;
    procedure Test_Insert_In_SQLite3;

    procedure Test_Update_In_Mysql;
    procedure Test_Update_In_Postgres;
    procedure Test_Update_In_SQLite3;

    procedure Test_Delete_In_Mysql;
    procedure Test_Delete_In_Postgres;
    procedure Test_Delete_In_SQLite3;

  end;

implementation

uses
  classes;

{ TestTDBx }

procedure TestTDBx.dbParams(driver, server, port, username, password, database, timeout: string);
begin
  with TDBX do
  begin
    KillConnection;
    _DRIVER := driver;
    _SERVER := server;
    _PORT := port;
    _USERNAME := username;
    _PASSWORD := password;
    _DATABASE := database;
    _TIMEOUT := timeout;
  end;
end;

procedure TestTDBx.deleteTest;
var
  aTableName, aColumnName: string;
begin

  aTableName := LowerCase(TFaker.otan);
  aColumnName := LowerCase(TFaker.otan);

  TDBX.createTable(aTableName, [aColumnName + ' int']);

  insert(aTableName, aColumnName);

  TDBX.execute('delete from ' + aTableName);

  CheckNull(TDBX.execute('select * from ' + aTableName));

  TDBX.dropTable(aTableName);

end;

procedure TestTDBx.dropDatabase(aDatabaseName: string);
begin

  TDBX.createDatabase(aDatabaseName);
  TDBX.dropDatabase(aDatabaseName);

  checkfalse(TDBX.databaseExists(aDatabaseName));

end;

procedure TestTDBx.dropTable;
var
  aTableName: string;
begin
  aTableName := LowerCase(TFaker.otan);

  TDBX.createTable(aTableName, ['name text']);

  TDBX.dropTable(aTableName);

  checkfalse(TDBX.tableExists(aTableName));

end;

procedure TestTDBx.backupDatabase(aDatabaseName: string; aFileDestination: string = '');
var
  abkpFile: TFileStream;
begin
  if aFileDestination.IsEmpty then
    aFileDestination := genBackupFileName(aDatabaseName);

  {
    windows troubles with path delimiter '\' for sqlite
    if pathdelim = '\' char(#220), replace all '\' chars to '\\'
  }

{$IFDEF MSWINDOWS}
  aFileDestination := aFileDestination.Replace('\', '\\');
{$ENDIF}
  TDBX.createDatabase(aDatabaseName);
  TDBX.backupDatabase(aDatabaseName, aFileDestination);
  TDBX.dropDatabase(aDatabaseName);

  CheckTrue(tfile.Exists(aFileDestination));

  abkpFile := tfile.Open(aFileDestination, TFileMode.fmOpen);
  CheckNotEquals(abkpFile.Size, 0);

  abkpFile.Free;

  tfile.delete(aFileDestination);
end;

function TestTDBx.genBackupFileName(aFileName: string): string;
begin
  result := GetCurrentDir + PathDelim + aFileName + '_' + formatdatetime('yyyy_mm_dd', now) + '.sql'
end;

function TestTDBx.insert(aTableName, aColumnName: string): Integer;
var
  i: Integer;
begin

  result := Random(99);

  for i := 1 to result do
    TDBX.execute('insert into ' + aTableName + '(' + aColumnName + ') values(' + inttostr(Random(999999)) + ')');

end;

procedure TestTDBx.insertTest;
var
  aTableName, aColumnName: string;
begin

  aTableName := LowerCase(TFaker.otan);
  aColumnName := LowerCase(TFaker.otan);

  TDBX.createTable(aTableName, [aColumnName + ' int']);

  CheckNotEquals(insert(aTableName, aColumnName), 0);

  TDBX.dropTable(aTableName);

end;

procedure TestTDBx.renameTable;
var
  aTableName, aNewTableName: string;
begin

  aTableName := LowerCase(TFaker.otan);
  aNewTableName := aTableName + '_' + LowerCase(TFaker.otan);

  TDBX.createTable(aTableName, ['price float']);
  TDBX.renameTable(aTableName, aNewTableName);

  CheckTrue(TDBX.tableExists(aNewTableName));
  checkfalse(TDBX.tableExists(aTableName));

  TDBX.dropTable(aNewTableName);

end;

procedure TestTDBx.connectMysql(aRunTests: Boolean = false);
begin
  connect('mysql', 'localhost', '3306', 'root', '1234', database_name, '5000', aRunTests);
end;

procedure TestTDBx.connectPostGres(aRunTests: Boolean = false);
begin
  connect('PG', 'localhost', '5432', 'postgres', 'postgres', database_name, '5000', aRunTests);
end;

procedure TestTDBx.connectSQLite3(aRunTests: Boolean = false);
var
  db_name: string;
begin
  db_name := sqlite_db;
  connect('sqlite', 'localhost', '', '', '', db_name, '5000', aRunTests);
  TDBX.KillConnection;
  TDBX.dropDatabase(db_name);
end;

procedure TestTDBx.createDatabase(aDatabaseName: string);
begin

  TDBX.createDatabase(aDatabaseName);
  CheckTrue(TDBX.databaseExists(aDatabaseName));

  TDBX.dropDatabase(aDatabaseName);

end;

function TestTDBx.selectCount(aTableName: string): Integer;
begin

  result := TDBX.execute('select count(*) from ' + aTableName).Fields[0].AsInteger;

end;

procedure TestTDBx.selectTest;
var
  aTableName, aColumnName: string;
  insertedCount: Integer;
begin

  aTableName := LowerCase(TFaker.otan);
  aColumnName := LowerCase(TFaker.otan);

  TDBX.createTable(aTableName, [aColumnName + ' int']);

  insertedCount := insert(aTableName, aColumnName);

  CheckEquals(insertedCount, selectCount(aTableName));

  TDBX.dropTable(aTableName);

end;

function TestTDBx.sqlite_db(dbName: string = ''): string;
begin
  if dbName = '' then
    result := GetCurrentDir + PathDelim + database_name + '.sqlite3'
  else
    result := GetCurrentDir + PathDelim + dbName + '.sqlite3';
end;

procedure TestTDBx.CreateAndExistsTable;
var
  aTableName: string;
begin
  aTableName := LowerCase(TFaker.otan);

  TDBX.createTable(aTableName, ['id int']);
  CheckTrue(TDBX.tableExists(aTableName));

  TDBX.dropTable(aTableName);
end;

procedure TestTDBx.TestDrop_Table_In_Mysql;
begin

  connectMysql;
  dropTable;

end;

procedure TestTDBx.TestDrop_Table_In_Postgres;
begin

  connectPostGres;
  dropTable;

end;

procedure TestTDBx.TestDrop_Table_In_SQLite3;
begin

  connectSQLite3;
  dropTable;

end;

procedure TestTDBx.Test_Backup_Database_In_Mysql;
begin

  connectMysql;
  backupDatabase(TFaker.otan);

  // change this configuration to your path for 'mysqldump'
  // or leave it blank to get default configuration
  TDBX.MySQL.MYSQLDUMP := 'D:\mysql\mysqldump.exe';
  backupDatabase(TFaker.otan);

end;

procedure TestTDBx.Test_Backup_Database_In_Postgres;
begin

  connectPostGres;
  backupDatabase(LowerCase(TFaker.otan));

  // change this configuration to your path for 'pg_dump'
  // or leave it blank to get default configuration
  TDBX.postgres.pg_dump := 'C:\PostgreSQL\pg96\bin\pg_dump.exe';
  backupDatabase(LowerCase(TFaker.otan));

end;

procedure TestTDBx.Test_Backup_Database_In_SQLite3;
var
  db_name: string;
begin

  connectSQLite3;
  db_name := TFaker.otan;
  backupDatabase(sqlite_db(db_name), genBackupFileName(db_name));

  // change this configuration to your path for 'sqlite'
  // or leave it blank to get default configuration
  TDBX.SQLite3.SQLite3 := 'C:\sqlite\sqlite3.exe';
  db_name := TFaker.otan;
  backupDatabase(sqlite_db(db_name), genBackupFileName(db_name));

end;

procedure TestTDBx.columnExists;
var
  aTableName, aColumnName: string;
begin

  aTableName := LowerCase(TFaker.otan);
  aColumnName := LowerCase(TFaker.otan);

  TDBX.createTable(aTableName, [aColumnName + ' int']);

  CheckTrue(TDBX.columnExists(aTableName, aColumnName));

  TDBX.dropTable(aTableName);

end;

procedure TestTDBx.connect(driver, server, port, username, password, database, timeout: string; aRunTests: Boolean = false);
var
  connection: TFDConnection;
begin
  with TDBX do
  begin
    dbParams(driver, server, port, username, password, database, timeout);
    connection := startConnection;
    if aRunTests then
    begin
      CheckTrue(connection <> nil);
      CheckTrue(connection.Connected);
    end;
  end;
end;

procedure TestTDBx.Test_Prevent_Connect_To_Invalid_Drive;
begin
  with TDBX do
  begin

    dbParams(TFaker.thing, 'localhost', inttostr(Random(9999)), TFaker.username, TFaker.password, TFaker.otan, '10000');

    StartExpectingException(EDriverNotSupported);
    startConnection;
    StopExpectingException();

  end;
end;

procedure TestTDBx.Test_Rename_Table_In_Mysql;
begin

  connectMysql;
  renameTable;

end;

procedure TestTDBx.Test_Rename_Table_In_Postgres;
begin

  connectPostGres;
  renameTable;

end;

procedure TestTDBx.Test_Rename_Table_In_SQLite3;
begin

  connectSQLite3;
  renameTable;

end;

procedure TestTDBx.Test_Column_Exists_In_Mysql;
begin

  connectMysql;
  columnExists;

end;

procedure TestTDBx.Test_Column_Exists_In_Postgres;
begin

  connectPostGres;
  columnExists;

end;

procedure TestTDBx.Test_Column_Exists_In_SQLite3;
begin

  connectSQLite3;
  columnExists;

end;

procedure TestTDBx.Test_Select_In_Mysql;
begin

  connectMysql;
  selectTest;

end;

procedure TestTDBx.Test_Select_In_Postgres;
begin

  connectPostGres;
  selectTest;

end;

procedure TestTDBx.Test_Select_In_SQLite3;
begin

  connectSQLite3;
  selectTest;

end;

procedure TestTDBx.Test_Connect_To_MySQL;
begin
  connectMysql(true);
end;

procedure TestTDBx.Test_Connect_To_Postgres;
begin
  connectPostGres(true);
end;

procedure TestTDBx.Test_Connect_To_SQLite3;
begin
  connectSQLite3(true);
end;

procedure TestTDBx.Test_Create_Database_And_Check_If_Exists_In_Mysql;
begin

  connectMysql;
  createDatabase(TFaker.otan);

end;

procedure TestTDBx.Test_Create_Database_And_Check_If_Exists_In_Postgres;
begin

  connectPostGres;
  createDatabase(LowerCase(TFaker.otan));

end;

procedure TestTDBx.Test_Create_Database_And_Check_If_Exists_In_SQLite3;
begin

  connectSQLite3;
  createDatabase(sqlite_db(TFaker.otan));

end;

procedure TestTDBx.Test_Create_Table_And_Check_If_Exists_In_Mysql;
begin

  connectMysql;
  CreateAndExistsTable;

end;

procedure TestTDBx.Test_Create_Table_And_Check_If_Exists_In_Postgres;
begin

  connectPostGres;
  CreateAndExistsTable;

end;

procedure TestTDBx.Test_Create_Table_And_Check_If_Exists_In_SQLite3;
begin

  connectSQLite3;
  CreateAndExistsTable;

end;

procedure TestTDBx.Test_Delete_In_Mysql;
begin

  connectMysql;
  deleteTest;

end;

procedure TestTDBx.Test_Delete_In_Postgres;
begin

  connectPostGres;
  deleteTest;

end;

procedure TestTDBx.Test_Delete_In_SQLite3;
begin

  connectSQLite3;
  deleteTest;

end;

procedure TestTDBx.Test_Drop_Database_In_Mysql;
begin

  connectMysql;
  dropDatabase(TFaker.otan);

end;

procedure TestTDBx.Test_Drop_Database_In_Postgres;
begin

  connectPostGres;
  dropDatabase(LowerCase(TFaker.otan));

end;

procedure TestTDBx.Test_Drop_Database_In_SQLite3;
begin

  connectSQLite3;
  dropDatabase(sqlite_db(TFaker.otan));

end;

procedure TestTDBx.Test_Insert_In_Mysql;
begin

  connectMysql;
  insertTest;

end;

procedure TestTDBx.Test_Insert_In_Postgres;
begin

  connectPostGres;
  insertTest;

end;

procedure TestTDBx.Test_Insert_In_SQLite3;
begin

  connectSQLite3;
  insertTest;

end;

procedure TestTDBx.Test_Kill_Connection;
begin
  CheckTrue(TDBX.KillConnection);
end;

procedure TestTDBx.Test_Update_In_Mysql;
begin

  connectMysql;
  updateTest;

end;

procedure TestTDBx.Test_Update_In_Postgres;
begin

  connectPostGres;
  updateTest;

end;

procedure TestTDBx.Test_Update_In_SQLite3;
begin

  connectSQLite3;
  updateTest;

end;

procedure TestTDBx.updateTest;
var
  aTableName, aColumnName, aValue, aNewValue: string;
begin

  aTableName := LowerCase(TFaker.otan);
  aColumnName := LowerCase(TFaker.otan);

  aValue := TFaker.text;
  aNewValue := TFaker.LOREM_IPSUM;

  TDBX.createTable(aTableName, [aColumnName + ' text']);

  TDBX.execute('insert into ' + aTableName + ' values (?)', [aValue]);
  TDBX.execute('update ' + aTableName + ' set ' + aColumnName + '=?', [aNewValue]);

  CheckNotNull(TDBX.execute('select * from ' + aTableName + ' where ' + aColumnName + '=?', [aNewValue]));
  CheckNull(TDBX.execute('select * from ' + aTableName + ' where ' + aColumnName + '=?', [aValue]));

  TDBX.dropTable(aTableName);

end;

initialization

RegisterTest(TestTDBx.Suite);

end.
