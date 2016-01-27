// RESTful ORM server for OpenUI5 demo
// does not server static content
// static content is done by a standard webserver like apache or its likes
program SAPUI5ServerDaemon;

{$IFDEF LINUX}
{$IFDEF CPUX86_64}
{$IFDEF FPC_CROSSCOMPILING}
{$linklib libc_nonshared.a}
{$ENDIF}
{$ENDIF}
{$ENDIF}

uses
  {$ifdef Linux}
  cthreads,
  {$endif}
  Classes,
  SysUtils,
  SampleData,
  dataserver,
  daemonapp;

type
  TTestDaemon = Class(TCustomDaemon)
  Private
    mORMotServer: TmORMotODataServer;
  public
    Function Start : Boolean; override;
    Function Stop : Boolean; override;
    Function Pause : Boolean; override;
    Function Continue : Boolean; override;
    Function Execute : Boolean; override;
    Function ShutDown : Boolean; override;
    Function Install : Boolean; override;
    Function UnInstall: boolean; override;
  end;

Procedure AWriteln(MSg : String; B : Boolean);
begin
  Application.Log(etcustom,Msg+BoolToStr(B));
end;

{ TTestDaemon }

function TTestDaemon.Start: Boolean;
begin
  Result:=inherited Start;

  AWriteln('Daemon Start',Result);

  mORMotServer:=TmORMotODataServer.Create;

  AWriteln('Server Start',Result);
end;

function TTestDaemon.Stop: Boolean;
begin
  Result:=inherited Stop;
  AWriteln('Daemon Stop: ',Result);
  FreeAndNil(mORMotServer);
end;

function TTestDaemon.Pause: Boolean;
begin
  Result:=inherited Pause;
  AWriteln('Daemon pause: ',Result);
end;

function TTestDaemon.Continue: Boolean;
begin
  Result:=inherited Continue;
  AWriteln('Daemon continue: ',Result);
end;

function TTestDaemon.Execute: Boolean;
begin
  Result:=inherited Execute;
  AWriteln('Daemon execute: ',Result);
end;

function TTestDaemon.ShutDown: Boolean;
begin
  Result:=inherited ShutDown;
  AWriteln('Daemon Shutdown: ',Result);
  FreeAndNil(mORMotServer);
  AWriteln('Server Shutdown: ',Result);
end;

function TTestDaemon.Install: Boolean;
begin
  Result:=inherited Install;
  AWriteln('Daemon Install: ',Result);
end;

function TTestDaemon.UnInstall: boolean;
begin
  Result:=inherited UnInstall;
  AWriteln('Daemon UnInstall: ',Result);
end;

Type

  { TTestDaemonMapper }

  TTestDaemonMapper = Class(TCustomDaemonMapper)
    Constructor Create(AOwner : TComponent); override;
  end;

{ TTestDaemonMapper }

constructor TTestDaemonMapper.Create(AOwner: TComponent);

Var
  D : TDaemonDef;

begin
  inherited Create(AOwner);
  D:=DaemonDefs.Add as TDaemonDef;
  D.DisplayName:='Test daemon';
  D.Name:='TestDaemon';
  D.DaemonClassName:='TTestDaemon';
  //D.WinBindings.ServiceType:=stWin32;
end;

begin
  RegisterDaemonClass(TTestDaemon);
  RegisterDaemonMapper(TTestDaemonMapper);
  Application.Run;
end.
