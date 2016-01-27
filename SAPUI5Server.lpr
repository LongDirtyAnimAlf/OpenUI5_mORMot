program SAPUI5Server;

{$I Synopse.inc}

uses
  Interfaces,
  Forms,
  Main in 'Main.pas' {Form1},
  SampleData in 'SampleData.pas', dataserver;

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
