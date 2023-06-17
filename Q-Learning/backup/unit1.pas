UNIT Unit1;

{$mode objfpc}{$H+}
{$appType console}
INTERFACE

USES
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  Grids;

TYPE

  { TForm1 }

  TForm1 = CLASS(TForm)
    Button_move: TButton;
    Button_start: TButton;
    Image_robbi: TImage;
    Label1: TLabel;
    Label10: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    Label7: TLabel;
    Label8: TLabel;
    Label9: TLabel;
    Label_Robbi_y: TLabel;
    Label_runs: TLabel;
    Label_failiures: TLabel;
    Label_successes: TLabel;
    Label_Robbi_x: TLabel;
    Shape1: TShape;
    Shape10: TShape;
    Shape11: TShape;
    Shape12: TShape;
    Shape2: TShape;
    Shape3: TShape;
    Shape4: TShape;
    Shape5: TShape;
    Shape6: TShape;
    Shape7: TShape;
    Shape8: TShape;
    Shape9: TShape;
    Timer_Move: TTimer;
    procedure Button_moveClick(Sender: TObject);
    procedure Button_startClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure Timer_MoveTimer(Sender: TObject);
  private

  public

  END;

VAR
  Form1: TForm1;

IMPLEMENTATION

{$R *.lfm}
//===================================================================
// Coder-Name: Agent_Matti
//===================================================================
//               eigene globale Deklarationen
//-------------------------------------------------------------------
TYPE State_t = Record
     x: integer;
     y: integer;
end;
TYPE Action = record
     up:REAl;
     right:REAl;
     down:REAl;
     left:REAl;
end;
Var Robbi: State_t;
Var Runs,Start_runs:Integer;
Var Epsilon:REAL;
Var learning_rate,Discount:Real;
Var Failiures,successes:WORD;
// define battlefield
// index start with 0
Const size_x = 4;
Const size_y = 3;
Const min_x = 0;
Const min_y = 0;
const max_reward = 100;
// one wall
Var wand: State_t;
Var goal: State_t;
Var loss: State_t;
// holds value per state and action related to reaching the target
// address: state.x, state.y, action
Var StateActionValues: array[min_x..size_x-1, min_y..size_y-1, 1..4] of real;
//===================================================================
//               eigene coole abgeschlossene Routinen
//-------------------------------------------------------------------
Function Runden(z:REAL;s:BYTE):REAL;
Var rh:LONGWORD;
Var i:BYTE;
begin
  rh:=1;
  For i:=1 TO s do rh:=rh*10;
  Result:=(round(z*rh))/rh;
end;
//===================================================================
//               zusammenfassende Hilfsroutinen
//-------------------------------------------------------------------
Procedure Action_up;
Begin
  Robbi.y:=Robbi.y-1;
end;
Procedure Action_right;
Begin
  Robbi.x:=Robbi.x+1;
end;
Procedure Action_down;
Begin
  Robbi.y:=Robbi.y+1;
end;
Procedure Action_left;
Begin
  Robbi.x:=Robbi.x-1;
end;


Function onFinishingSquare(pos:State_t):Boolean;
Begin
  if ((pos.x = goal.x) and (pos.y = goal.y)) or((pos.x = loss.x) and (pos.y = loss.y)) then result:=true
    else Result:=false;
end;


Function invalid_state(s: State_t):BOOLEAN;
Begin
  // wenn robbi außerhalb des feldes
  if (s.x < min_x) or
     (s.x > (min_x + size_x - 1)) or
     (s.y < min_y) or
     (s.y > (min_y + size_y - 1)) or
     //oder in der wand ist
     ((s.x = wand.x) and (s.y = wand.y))
     //return true
     then Result := True
  else Result := False
end;

Procedure Random_Robbi_pos;
Var pos:State_t;
Var successfull:Boolean;
Begin
  // "successfull" is there to indicete wether a valid position was found
  successfull:=false;
  While not(successfull=true) Do
        Begin
        // decide a random position
        pos.x:=Random(4);
        pos.y:=Random(3);
        // check if the position is valid, repeat if not
        If (Invalid_State(pos) or onFinishingSquare(pos)) then successfull:= false
        else Begin
             //get robbi to the decided position, end the process
             Robbi:=pos;
             successfull:=true;
             end;
     //   WriteLn(inttostr(successfull));
  end;
end;

Procedure start_over;
Begin
  //sicergehen,dass der timer läuft
  Form1.Timer_Move.Enabled:=TRUE;
  //"neu würfeln"
  randomize;
  //robbi auf eine zufällige position setzen
  Random_Robbi_pos;
  Runs:=runs-1;
  Writeln('new beginning new pos: '+inttostr(robbi.x)+', '+inttostr(Robbi.y))
end;

Function Reward(pos:State_t):Integer;
Begin
  //big reward for winning State_t
  If (pos.y=0) and (pos.x=3) then Result:=100
  //big negative reward for losing State_t
  else
    If (pos.y=1) and (pos.x=3) then Result:=-100
  //small negative reward for normal State_t
  else
    Result:=-1;
end;



Function getMaxActionValueForState(pos:State_t): real;
Var act:action;
begin
  //get all the values for the actions
  act.up:= StateActionValues[pos.x,pos.y,1];
  act.right:= StateActionValues[pos.x,pos.y,2];
  act.down:= StateActionValues[pos.x,pos.y,3];
  act.left:= StateActionValues[pos.x,pos.y,4];
  //get the biggest action value and return it
  Result:=0;
  if act.up>Result then Result:=act.up;
  if act.right>Result then Result:=act.right;
  if act.down>Result then Result:=act.down;
  if act.left>Result then Result:=act.left;
end;

Function getMinActionValueForState(pos:State_t): real;
Var act:action;
begin
  //get all the values for the actions
  act.up:= StateActionValues[pos.x,pos.y,1];
  act.right:= StateActionValues[pos.x,pos.y,2];
  act.down:= StateActionValues[pos.x,pos.y,3];
  act.left:= StateActionValues[pos.x,pos.y,4];
  //get the biggest action value and return it
  Result:=0;
  if act.up<Result then Result:=act.up;
  if act.right<Result then Result:=act.right;
  if act.down<Result then Result:=act.down;
  if act.left<Result then Result:=act.left;
end;

Function getBestActionForState(pos:State_t): Byte;
Var best:real;
    curAction, a, s, selectedAction: Byte;
Var resActions: array[1..4] of Byte;
begin
  //get the biggest action value
  best:=getMaxActionValueForState(pos);

  //initialize array
  for a:=1 to length(resActions) do resActions[a]:=0;


  // s ist die anzahl der besten actions
  s:=0;

  //check which action has the most value
  for curAction := 1 to 4 do
  begin
    if best = StateActionValues[pos.x,pos.y,curAction] then
    begin
      s:=s+1;
      // save action
      resActions[s]:=curAction;
    end;
  end;
   // Select a random action from the best actions
  selectedAction:= resActions[Random(s)+1];



  //return the most valuable action as a number
  Result := selectedAction;
  //WriteLn(inttostr(Result));

end;

Function KomplizierteGleichung(new_Pos:State_t):Real;
Var Ergebnis:REAL;
Begin
  Ergebnis:= getMaxActionValueForState(new_pos);
  Ergebnis:= Ergebnis + Reward(new_pos);
  Ergebnis:= Ergebnis * discount;
  Result:= Runden(Ergebnis,3);
end;

procedure setValue4StateAction(old_pos:State_t; Action_taken:Integer;new_pos:State_t);
Var oldStateActionValue, newStateActionValue: Real;
begin
  oldStateActionValue := StateActionValues[old_pos.x,old_pos.y,Action_taken];
  //Calculate the new stateactionValue for the action just taken
  // the old StateActionvalue is not cmpletely replaced in case the value for the taken action is based on a random event(learning rate)

  newStateActionValue := KomplizierteGleichung(new_Pos);

  //newStateActionValue:= oldStateActionValue+learning_rate*((Reward(new_pos)+Discount*(getMaxActionValueForState(new_pos)))-oldStateActionValue);

  StateActionValues[old_pos.x,old_pos.y,Action_taken]:=newStateActionValue;

 // WriteLn(Floattostr);
end;

Procedure update_robbi;
Begin
  //verschiebt robbi auf der y coord
  Form1.Image_robbi.top:=Robbi.y*64+16;

  //verschiebt robbi auf der x coord
  Form1.Image_robbi.left:=Robbi.x*64+16;

  //zeigt robbis position in zahlen an
  Form1.Label_Robbi_x.caption:= inttostr(robbi.x);
  Form1.Label_Robbi_y.caption:= inttostr(robbi.y);

end;

Function game_end(x,y:BYTE):Boolean;
Begin
  //check if won
  If (x = 3) and (y = 0) then
    Begin
      Result:=true;
      Successes:=successes+1;
      writeln('won');
    end
  //or if lost
  Else If (x = 3) and (y = 1) then
    Begin
      result:=true;
      Failiures:=Failiures+1;
      writeln('lost');
    end
  //ansonsten weitermachen
  else result:=false;
end;


Procedure takeAction(act:Integer);
Begin
  CASE act of
         1        : Action_up;
         2        : Action_right;
         3        : Action_down;
         4        : Action_left;
  end;

end;

// . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .
Procedure Move;
Var decision:BYTE;
Var Old_robbi:State_t;
Begin

  //vorherige position von robbi speichern
  Old_robbi.x:=Robbi.x;
  old_robbi.y:=Robbi.y;

  //    Explore/Exploit
//  If Random(10)+1 = 1 then
//      //random move
//      decision:=random(4)+1
//    else
      //most valued action
      decision:=getBestActionForState(Robbi);

  //execute the decision
  takeAction(decision);
 // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  //wenn außerhalb des feldes, setze position zurück
  If (Invalid_state(Robbi)) Then
    Begin
    //setze position zurück
    robbi.x:=Old_Robbi.x;
    robbi.y:=Old_Robbi.y;;

    end;

 // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
 //Update the value for the action just taken
 setValue4StateAction(Old_robbi,decision,robbi);

 Writeln('old Pos: ' + inttostr(Old_robbi.x) + ', ' + inttostr(Old_robbi.y) + '; Action: '+inttostr(decision)+'; new Pos: '+inttostr(robbi.x)+', '+inttostr(Robbi.y)+'; Reward: '+inttostr( Reward(Robbi) )  );
 Writeln('best state-action-Value: '+floattostr(getMaxActionValueForState(robbi))+'; worst state-action-Value: ' + floattostr(getMinActionValueForState(robbi)) +  '; random next best next action: ' + inttostr(getBestActionForState(robbi)));
 // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
 //check if game ended und dann neustarten
 If game_end(Robbi.x,robbi.y) then
   Begin
     //Runs:=Runs-1;         //needs to be added again, just removed for manual testing
     start_over;
   end;
 //wins and losses anzeigen
  Form1.Label_successes.caption:= inttostr(successes);
  Form1.Label_failiures.caption:= inttostr(Failiures);
 // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  //zeige robbis position graphisch an
  Update_robbi;


  // - - - - - -- - - - - -- - - -- - - -- - - - - -- - - - - -- - - - - - - --

end;

procedure initBattleField ();
var x,y,a: integer;
begin
 // init walls
 wand.x := 1;
 wand.y := 1;
 //init Goal/loss
 Goal.x:= 3;
 Goal.y:= 0;
 loss.x:= 3;
 loss.y:= 1;
 // init values
 for x := min_x to min_x + (size_x-1) do
 begin
   for y := min_y to min_y + (size_y-1) do
   begin
     for a := 1 to 4 do
       StateActionValues[x,y,a] := 0.0;
     begin
     end; // for action
   end; // for y
 end; // for x
  StateActionValues[Goal.x,Goal.y,1]:= max_reward;
  StateActionValues[loss.x,loss.y,1]:= -max_reward;
end;

// . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .


//===================================================================
//               Ereignisbehandlungsroutinen (EBR)
//-------------------------------------------------------------------

{ TForm1 }

procedure TForm1.FormCreate(Sender: TObject);
begin
  Form1.Timer_Move.Enabled:=false;
  Form1.Timer_Move.Interval:= 100;
  randomize;
  Robbi.x := 0;
  Robbi.y := 2;
  Start_Runs:=52;
  Epsilon:=0.9;
  learning_rate:=0.9;
  Discount:=0.9;
  Successes:=0;
  Failiures:=0;
  initBattleField();

  start_over;
  update_robbi;
end;

procedure TForm1.Button_startClick(Sender: TObject);
begin
  Runs:=Start_Runs;
  start_over;
end;

procedure TForm1.Button_moveClick(Sender: TObject);
begin
  Move;
end;

procedure TForm1.Timer_MoveTimer(Sender: TObject);
Var i:Integer;
begin
  If Runs > 0 Then Begin
  //  For i:=1 to 1 DO Begin
    Move;
    Form1.Label_runs.caption:=IntToStr(Runs);
    Form1.Refresh;
    //End
  end;
end;


END.

