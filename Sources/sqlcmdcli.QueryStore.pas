unit sqlcmdcli.QueryStore;

interface

type
  TQueryStoreWorkload = class(TObject)
  public
    class procedure Run(const AServerName, ADatabaseName, AUserName, APassword: string;
      AVerbose: Boolean);
  end;

implementation

uses
  System.SysUtils
  ,System.Classes
  ,Data.Win.ADODB
  ,FireDAC.Comp.Client
  ,FireDAC.Stan.Def
  ,FireDAC.Stan.Param
  ,FireDAC.DApt
  ,WinApi.ActiveX
  ,sqlcmdcli.ResourceStrings
  ,sqlcmdcli.console;

{ TWorkload }

class procedure TQueryStoreWorkload.Run(const AServerName, ADatabaseName, AUserName,
  APassword: string; AVerbose: Boolean);
var
  Li: Integer;
  LRandomInteger: Integer;
  LStopValue: Integer;
  LPct: Integer;
  //LFDConnection: TFDConnection;
  //LFDQuery, LFDQueryFreeCache: TFDQuery;
  LConnection: TADOConnection;
  LQuery, LQueryFreeCache, LQrySetupDB: TADOQuery;
begin
  CoInitialize(nil);

  LStopValue := 300000;

  //LConnection := TFDConnection.Create(nil);
  //LQuery := TFDQuery.Create(nil);
  //LQueryFreeCache := TFDQuery.Create(nil);
  LConnection := TADOConnection.Create(nil);
  LQuery := TADOQuery.Create(nil);
  LQueryFreeCache := TADOQuery.Create(nil);
  LQrySetupDB := TADOQuery.Create(nil);

  try  // finally
    try
      // Build the connection string

      // FireDAC
      //LConnection.ConnectionString :=
      //  'DriverID=MSSQL;' +
      //  'Persist Security Info=False;' +
      //  'User_Name=' + AUserName + ';' +
      //  'Password=' + APassword + ';' +
      //  'Database=' + ADatabaseName + ';' +
      //  'Server=' + AServerName + ';';

      // ADO
      LConnection.ConnectionString :=
        'Provider=SQLNCLI10.1;' +
        //'Integrated Security="";' +
        'Persist Security Info=False;' +
        //'User ID=' + AUserName + '@' + AServerName + ';' +
        'User ID=' + AUserName + ';' +
        'Password=' + APassword + ';' +
        'Initial Catalog=' + ADatabaseName + ';' +
        'Data Source=' + AServerName + ';' +
        'Initial File Name="";' +
        'Server SPN=""';
      LConnection.Connected := True;
      if (AVerbose) then
        TConsole.Log(Format(RS_CONNECTION_SUCCESSFULLY, [AServerName]), Success, True);

      LQuery.Connection := LConnection;
      LQueryFreeCache.Connection := LConnection;
      LQrySetupDB.Connection := LConnection;

      // Setup database
      if (AVerbose) then
        TConsole.Log(Format(RS_SETUP_DATABASE_BEGIN, [ADatabaseName]), Info, True);

      LQrySetupDB.SQL.Text :=
        'DROP TABLE IF EXISTS dbo.#Tab_A;';
      LQrySetupDB.ExecSQL;

      LQrySetupDB.SQL.Text :=
        'CREATE TABLE dbo.#Tab_A (Col1 INTEGER, Col2 INTEGER, Col3 BINARY(2000));';
      LQrySetupDB.ExecSQL;

      LQrySetupDB.SQL.Text :=
        'SET NOCOUNT ON ' +
        'BEGIN ' +
          'BEGIN TRANSACTION ' +
          'DECLARE @i INTEGER = 0 ' +
          'WHILE (@i < 10000) ' +
          'BEGIN ' +
            'INSERT INTO dbo.#Tab_A (Col1, Col2) VALUES (@i, @i) ' +
	          'SET @i+=1 ' +
          'END ' +
          'COMMIT TRANSACTION ' +
        'END ' +
        'SET NOCOUNT OFF';
      LQrySetupDB.ExecSQL;

      LQrySetupDB.SQL.Text :=
        'INSERT INTO dbo.#Tab_A (Col1, Col2) VALUES (1, 1)';
      for Li := 1 to 100000 do
        LQrySetupDB.ExecSQL;

      LQrySetupDB.SQL.Text :=
        'CREATE INDEX IDX_Tab_A_Col1 ON dbo.#Tab_A (Col1)';
      LQrySetupDB.ExecSQL;

      LQrySetupDB.SQL.Text :=
        'CREATE INDEX IDX_Tab_A_Col2 ON dbo.#Tab_A (Col2)';
      LQrySetupDB.ExecSQL;

      LQuery.SQL.Text := 'ALTER DATABASE CURRENT SET QUERY_STORE CLEAR ALL';
      LQuery.ExecSQL;

      // Clear the Query Store
      if (AVerbose) then
        TConsole.Log(Format(RS_SETUP_DATABASE_CLEAR_QUERY_STORE, [ADatabaseName]), Info, True);

      if (AVerbose) then
        TConsole.Log(Format(RS_SETUP_DATABASE_END, [ADatabaseName]), Info, True);

      for Li := 1 to LStopValue do
      begin
        LRandomInteger := Random(100);
        LPct := Trunc((Li * 1.0 / LStopValue) * 100);
        TConsole.Log(Format(RS_STATUS_MSG, [Li, LStopValue, LPct]) +
                     Format(RS_QRY_QUERYSTORE_REGRESSION, [LRandomInteger, LRandomInteger]), Info, False);

        LQuery.SQL.Text :=
          'SELECT * ' +
          'FROM dbo.#Tab_A ' +
          'WHERE (Col1= :pCol1) AND (Col2= :pCol2)';

        // ADO
        LQuery.Parameters[0].Value := LRandomInteger;
        LQuery.Parameters[1].Value := LRandomInteger;

        // FireDAC
        //LQuery.Params[0].Value := LRandomInteger;
        //LQuery.Params[1].Value := LRandomInteger;

        if (Random(100) < 2) then
        begin
          LQueryFreeCache.SQL.Text := 'DBCC FREEPROCCACHE';
          LQueryFreeCache.ExecSQL;
          //TConsole.Log(Format(RS_STATUS_MSG, [Li, LStopValue, LPct]) + 'DBCC FREEPROCCACHE', Info);
        end;

        LQuery.Open;

        while ((not LQuery.Eof) and (LRandomInteger <> 1)) do
        begin
          //
          LQuery.Next;
        end;

        LQuery.Close;
      end;

    except
      on E: Exception do
        Writeln(E.ClassName, ': ', E.Message);
    end;

  finally
    FreeAndNil(LConnection);
    FreeAndNil(LQuery);
    FreeAndNil(LQueryFreeCache);
    CoUninitialize;
  end;
end;

end.
