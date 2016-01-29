program SAPUI5Server;

uses
  Forms,
  Main in 'Main.pas' {Form1},
  SampleData in 'SampleData.pas',
  dataserver in 'dataserver.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
