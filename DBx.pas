unit DBx;

interface

uses
  Firedac.comp.client,
  Firedac.comp.dataset,
  Firedac.comp.UI,
  Firedac.stan.Option,
  Firedac.DApt,
  Firedac.stan.Def,
  Firedac.Phys.ADS,
  Firedac.Phys.ADSWrapper,
  Firedac.Phys.ASA,
  Firedac.Phys.ASAWrapper,
  Firedac.Phys.DB2,
  Firedac.Phys.DS,
  Firedac.Phys.FB,
  Firedac.Phys.IB,
  Firedac.Phys.IBBase,
  Firedac.Phys.IBWrapper,
  Firedac.Phys.Infx,
  Firedac.Phys.MSAcc,
  Firedac.Phys.MSSQL,
  Firedac.Phys.MySQL,
  Firedac.Phys.MySQLWrapper,
  Firedac.Phys.ODBC,
  Firedac.Phys.ODBCBase,
  Firedac.Phys.ODBCWrapper,
  Firedac.Phys.Oracle,
  Firedac.Phys.OracleWrapper,
  Firedac.Phys.PG,
  Firedac.Phys.PGWrapper,
  Firedac.Phys.SQLite,
  Firedac.Phys.SQLiteVDataSet,
  Firedac.Phys.SQLiteWrapper,
  Firedac.Phys.TDBX,
  Firedac.Phys.TDBXBase,
  Firedac.UI.Intf,
  Firedac.stan.Async,
  Firedac.stan.error;

type
  EDriverNotSupported = class(EFDException)
  end;

type
  TDBX = class
  private const
    SUPPORTED_DRIVERS: array [0 .. 2] of string = ('mysql', 'PG', 'sqlite');
    RESULT_COMMANDS: array [0 .. 1] of string = ('select', 'pragma');

    class procedure raiseDriverError;
    class procedure shell(xComand: String);

  class var
    mysqlDriver: TFDPhysMySQLDriverLink;
    postgresDriver: TFDPhysPgDriverLink;
    firebirdDriver: TFDPhysFBDriverLink;
    sqliteDriver: TFDPhysSQLiteDriverLink;
    mssqlDriver: TFDPhysMSSQLDriverLink;

    connection: TFDConnection;

  public Type
    MySQL = class
    public
      class var MYSQLDUMP: string; // default 'mysqldump'

    const
      ID = 'id int primary key auto_increment';
      CREATED = 'created timestamp default current_timestamp';
    end;

  type
    Postgres = class

    public
      class var PG_DUMP: string; // default 'pg_dump'

    const
      ID = 'ID SERIAL PRIMARY KEY';
      CREATED = 'created timestamp default now()';
    end;

  type
    SQLite3 = class
    public
      class var SQLite3: string; // default 'sqlite3'

    const
      ID = 'ID INTEGER PRIMARY KEY AUTOINCREMENT';
      CREATED = 'created timestamp default current_timestamp';
    end;

  class var
    _DRIVER: string;
    _SERVER: string;
    _PORT: string;
    _USERNAME: string;
    _PASSWORD: string;
    _DATABASE: string;
    _TIMEOUT: string;

    class function killConnection: boolean;
    class function startConnection: TFDConnection;

    class function execute(pSql: string): TFDQuery; overload;
    class function execute(pSql: string; pParams: array of variant): TFDQuery; overload;

    class procedure createDatabase(const pDbName: string);
    class function databaseExists(const pDbName: string): boolean;
    class procedure dropDatabase(const pDbName: string);
    class procedure backupDatabase(const pDbName, pFileDestination: string);

    class procedure createTable(const pTableName: string; const pColumns: array of string);
    class function tableExists(const pTableName: string): boolean;
    class procedure dropTable(const pTableName: string);
    class procedure clearTable(const pTableName: string);
    class procedure renameTable(const pFromTable, pToTable: string);
    class function columnExists(const pTableName, pColumnName: string): boolean;

  end;

implementation

uses strutils, types, data.db, System.SysUtils, System.IOUtils, Winapi.Windows;

{ TDBx }

class function TDBX.execute(pSql: string): TFDQuery;
begin
  result := TDBX.execute(pSql, []);
end;

class procedure TDBX.backupDatabase(const pDbName, pFileDestination: string);
begin
  TDBX._DATABASE := '';

  case AnsiIndexStr(TDBX._DRIVER, SUPPORTED_DRIVERS) of

    0: // mysql
      TDBX.shell(IfThen(TDBX.MySQL.MYSQLDUMP = '', 'mysqldump', TDBX.MySQL.MYSQLDUMP) + ' -h' + TDBX._SERVER + ' -u' + TDBX._USERNAME +
        ' -p' + TDBX._PASSWORD + ' -c -e --databases ' + pDbName + ' --result-file=' + pFileDestination);

    1: // Postgres (PG)
      // 'set PGPASSWORD=' + TDBX._PASSWORD + ' && ' + ' --dbname ' + pDbName + '
      TDBX.shell(IfThen(TDBX.Postgres.PG_DUMP = '', 'pg_dump', TDBX.Postgres.PG_DUMP) + ' --host ' + TDBX._SERVER + ' --port ' + TDBX._PORT
        + ' --username ' + TDBX._USERNAME + '  --format custom --file ' + pFileDestination + ' ' + pDbName);

    2: // sqlite
      TDBX.shell(IfThen(TDBX.SQLite3.SQLite3 = '', 'sqlite3', TDBX.SQLite3.SQLite3) + ' ' + pDbName + ' -cmd ".output ' + pFileDestination +
        '" ".dump"');

  else
    TDBX.raiseDriverError;
  end;
  FreeConsole;
end;

class procedure TDBX.clearTable(const pTableName: string);
begin
  TDBX.execute('delete from ' + pTableName);
end;

class function TDBX.columnExists(const pTableName, pColumnName: string): boolean;
var
  qry: TFDQuery;
begin
  case AnsiIndexStr(TDBX._DRIVER, SUPPORTED_DRIVERS) of

    0: // mysql
      result := TDBX.execute('select * from information_schema.columns where column_name = ? and table_name = ? and table_schema = ?',
        [pColumnName, pTableName, TDBX._DATABASE]) <> nil;

    1: // Postgres (PG)
      result := TDBX.execute('select * from information_schema.columns where column_name = ? and table_name = ? and table_catalog = ?',
        [pColumnName, pTableName, TDBX._DATABASE]) <> nil;

    2: // sqlite
      begin
        result := false;
        qry := TDBX.execute('PRAGMA table_info(' + pTableName + ')');
        if qry <> nil then
        begin
          with qry do
          begin
            first;
            while not eof do
            begin
              result := qry.FieldByName('name').AsString = pColumnName;
              if result then // find column in table
                Exit;
              Next;
            end;
          end;
        end;
      end;
  else
    TDBX.raiseDriverError;
  end;
end;

class procedure TDBX.createDatabase(const pDbName: string);
begin
  TDBX._DATABASE := '';

  case AnsiIndexStr(TDBX._DRIVER, SUPPORTED_DRIVERS) of

    0, 1: // mysql, Postgres (PG)
      TDBX.execute('create database ' + pDbName);

    2: // sqlite
      TFile.Create(pDbName).Free;

  else
    TDBX.raiseDriverError;
  end;
end;

class procedure TDBX.createTable(const pTableName: string; const pColumns: array of string);
var
  script, c: string;
begin
  script := 'create table ' + pTableName + ' (';
  for c in pColumns do
    script := script + c + ',';
  script := script.Remove(Length(script) - 1) + ')';
  TDBX.execute(script);
end;

class function TDBX.databaseExists(const pDbName: string): boolean;
begin
  case AnsiIndexStr(TDBX._DRIVER, SUPPORTED_DRIVERS) of

    0: // mysql
      result := TDBX.execute('select * from information_schema.schemata where schema_name = ?', [pDbName]) <> nil;

    1: // Postgres(PG)
      result := TDBX.execute('select * from pg_catalog.pg_database where datname = ?', [pDbName]) <> nil;

    2: // sqlite
      result := TFile.Exists(pDbName, false);

  else
    TDBX.raiseDriverError;
  end;
end;

class procedure TDBX.dropDatabase(const pDbName: string);
begin
  TDBX._DATABASE := '';
  case AnsiIndexStr(TDBX._DRIVER, SUPPORTED_DRIVERS) of

    0, 1: // mysql, Postgres(PG)
      TDBX.execute('drop database ' + pDbName);

    2: // sqlite
      TFile.delete(pDbName);

  else
    TDBX.raiseDriverError;
  end;
end;

class procedure TDBX.dropTable(const pTableName: string);
begin
  TDBX.execute('drop table ' + pTableName);
end;

class function TDBX.execute(pSql: string; pParams: array of variant): TFDQuery;
var
  i: integer;
  firstCommand: string;
begin
  result := TFDQuery.Create(nil);
  with result do
  begin
    connection := TDBX.startConnection;
    active := false;
    close;
    sql.Clear;
    sql.Add(pSql);
    for i := Low(pParams) to High(pParams) do
      params[i].value := pParams[i];

    // Here, we match the first blankspace and capture the first argument
    // from the sql command
    // Then, we determine what kind operation must be executed
    // Open or ExecSQL

    firstCommand := LowerCase(copy(pSql, 1, (ansipos(' ', pSql) - 1)));

    if ansimatchstr(firstCommand, RESULT_COMMANDS) then
    begin
      open;
      active := true;
      FetchAll;
      if recordcount = 0 then
        result := nil;
    end
    else
      ExecSQL;
  end;
end;

class function TDBX.startConnection: TFDConnection;
begin

  if not ansimatchstr(TDBX._DRIVER, SUPPORTED_DRIVERS) then
    TDBX.raiseDriverError;

  if connection = nil then
  begin

    connection := TFDConnection.Create(nil);

    with connection do
    begin

      Connected := false;
      params.BeginUpdate;
      params.Clear;
      params.endUpdate;

      ResourceOptions.AutoReconnect := false;
      params.BeginUpdate;

      LoginPrompt := false;

      params.Values['Server'] := TDBX._SERVER;
      params.Values['Port'] := TDBX._PORT;
      params.Values['Database'] := TDBX._DATABASE;
      params.Values['User_name'] := TDBX._USERNAME;
      params.Values['Password'] := TDBX._PASSWORD;
      params.Values['DriverID'] := TDBX._DRIVER;
      params.Values['LoginTimeout'] := TDBX._TIMEOUT;

      params.endUpdate;

    end;
  end;

  connection.ResourceOptions.AutoReconnect := true;
  connection.ResourceOptions.SilentMode := true;
  connection.ConnectedStoredUsage := [auDesignTime, auRunTime];
  connection.Connected := true;

  result := connection;

end;

class function TDBX.killConnection: boolean;
begin
  result := false;
  if connection <> nil then
    with connection do
    begin
      Connected := false;
      Destroy;
    end;
  connection := nil;
  result := true;
end;

class procedure TDBX.raiseDriverError;
begin
  raise EDriverNotSupported.Create(Format('Driver [%s] is not supported.', [TDBX._DRIVER]));
end;

class procedure TDBX.renameTable(const pFromTable, pToTable: string);
begin
  case AnsiIndexStr(TDBX._DRIVER, SUPPORTED_DRIVERS) of

    0: // mysql
      TDBX.execute('RENAME TABLE ' + pFromTable + ' TO ' + pToTable);

    1, 2: // postgres (PG), sqlite
      TDBX.execute('ALTER TABLE ' + pFromTable + ' RENAME TO ' + pToTable);

  else
    TDBX.raiseDriverError
  end;
end;

class procedure TDBX.shell(xComand: String);
var
  tmpStartupInfo: TStartupInfo;
  tmpProcessInformation: TProcessInformation;
  tmpProgram: String;
  aMsg: TMsg;
begin
  tmpProgram := trim(xComand);
  FillChar(tmpStartupInfo, SizeOf(tmpStartupInfo), 0);
  with tmpStartupInfo do
  begin
    cb := SizeOf(TStartupInfo);
    wShowWindow := SW_HIDE;
  end;
  if CreateProcess(nil, pchar(tmpProgram), nil, nil, true, CREATE_NO_WINDOW, nil, nil, tmpStartupInfo, tmpProcessInformation) then
  begin
    while WaitForSingleObject(tmpProcessInformation.hProcess, 10) > 0 do
      PeekMessage(aMsg, 0, 0, 0, 0);
    CloseHandle(tmpProcessInformation.hProcess);
    CloseHandle(tmpProcessInformation.hThread);
  end
  else
    RaiseLastOSError;
end;

class function TDBX.tableExists(const pTableName: string): boolean;
begin
  case AnsiIndexStr(TDBX._DRIVER, SUPPORTED_DRIVERS) of

    0: // mysql
      result := TDBX.execute('select * from information_schema.tables where table_name = ? and table_schema = ?',
        [pTableName, TDBX._DATABASE]) <> nil;

    1: // postgres (PG)
      result := TDBX.execute('select * from information_schema.tables where table_name = ? and table_catalog = ?',
        [pTableName, TDBX._DATABASE]) <> nil;

    2: // sqlite
      result := TDBX.execute('SELECT * FROM sqlite_master where type = "table" and tbl_name = ?', [pTableName]) <> nil;

  else
    TDBX.raiseDriverError
  end;
end;

end.
