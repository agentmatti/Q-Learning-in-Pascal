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

Const
    size_x = 4;//max x coordinate of the field
    size_y = 3;//max y coordinate of the field
    min_x = 0;//min x coordinate of the field
    min_y = 0;//min y coordinate of the field
    max_reward = 100;//the reward the agent gets when winning
    living_penalty = -1;//the penalty the agent gets every move
    anzActions = 4;//the number of actions the agent can take
    Epsilon = 10;//the probability in percent for the agent to take a random action
    //learning_rate
    Discount = 0.9;//the factor theStateActionValue gets decreased by

TYPE tState = Record
     x: integer;
     y: integer;
end;

TYPE tStateActionValues = Array[min_x..size_x-1,
                                min_y..size_y-1,
                                1..anzActions]
                                of real;

Var Robbi: tState;
    Runs,Start_runs:Integer;
    Failures,successes:WORD;
//    Discount: REAL;

// one wall
Var wand: tState;
Var goal: tState;
Var loss: tState;

// holds value per state and action related to reaching the target
// address: state.x, state.y, action
Var IdkWhatToCallThis: tStateActionValues;
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
Procedure takeAction(act:Integer);
Begin
  CASE act of
         1        : Action_up;
         2        : Action_right;
         3        : Action_down;
         4        : Action_left;
  end;
end;

Function onFinishingSquare(pos:tState):Boolean;
Begin
  if ((pos.x = goal.x) and (pos.y = goal.y)) or
     ((pos.x = loss.x) and (pos.y = loss.y)) then result:=true
    else Result:=false;
end;


Function invalid_state(pos: tState):BOOLEAN;
Begin
  // wenn robbi außerhalb des feldes
  if (pos.x < min_x) or
     (pos.x > (min_x + size_x - 1)) or
     (pos.y < min_y) or
     (pos.y > (min_y + size_y - 1)) or
     //oder in der wand ist
     ((pos.x = wand.x) and (pos.y = wand.y))
     //return true
     then Result := True
  else Result := False
end;

Procedure Random_Robbi_pos;
Var pos:tState;
Var successfull:Boolean;
Begin
  // "successfull" is there to indicate whether a valid position was found
  successfull:=false;
  While not successfull Do
        Begin
        // decide a random position
        pos.x:=Random(size_x);
        pos.y:=Random(size_y);
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
  //"neu würfeln"
  randomize;
  //robbi auf eine zufällige position setzen
  Random_Robbi_pos;
  Runs:=runs-1;
  Writeln('new beginning new pos: '+inttostr(robbi.x)+', '+inttostr(Robbi.y))
end;

Function Reward(pos:tState):Integer;
Begin
  //big reward for winning State
  If (pos.y=goal.y) and (pos.x=goal.x) then Result:= max_reward
  else
    //big negative reward for losing State
    If (pos.y=loss.y) and (pos.x=loss.x) then Result:=-max_reward
  else
    //small negative reward for normal State
    Result:=living_penalty;
end;


Function getMaxActionValueForState(pos:tState): real;
Var i: BYTE;
begin
  Result:= IdkWhatToCallThis[pos.x,pos.y,1];

  for i:=2 to length(IdkWhatToCallThis[pos.x,pos.y]) DO
      if Result<IdkWhatToCallThis[pos.x,pos.y,i] then Result:=IdkWhatToCallThis[pos.x,pos.y,i];
end;

Function getMinActionValueForState(pos:tState): real;
Var i: BYTE;
begin
  Result:= IdkWhatToCallThis[pos.x,pos.y,1];

  for i:=2 to length(IdkWhatToCallThis[pos.x,pos.y]) DO
      if Result>IdkWhatToCallThis[pos.x,pos.y,i] then Result:=IdkWhatToCallThis[pos.x,pos.y,i];
end;

Function getBestActionForState(pos:tState): Byte;
Var best:real;
    curAction, s, selectedAction: Byte;
Var resActions: array[1..4] of Byte;
begin
  //get the biggest action value
  best:=getMaxActionValueForState(pos);

  // s is the nuber of best actions
  s:=0;

  //check which action has the most value
  for curAction := 1 to 4 do
   begin
    if best = IdkWhatToCallThis[pos.x,pos.y,curAction] then
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


end;

Function KomplizierteGleichung(new_Pos:tState):Real;
Var Ergebnis:REAL;
Begin
  Ergebnis:= getMaxActionValueForState(new_pos);
  Ergebnis:= Ergebnis + Reward(new_pos);
  Ergebnis:= Ergebnis * discount;
  Result:= Runden(Ergebnis,3);
end;

procedure setValue4StateAction(old_pos:tState; Action_taken:Integer;new_pos:tState);
Var newStateActionValue: Real;
begin
  //Calculate the new stateactionValue for the action just taken
  newStateActionValue := KomplizierteGleichung(new_Pos);
  //newStateActionValue:= oldStateActionValue+learning_rate*((Reward(new_pos)+Discount*(getMaxActionValueForState(new_pos)))-oldStateActionValue);

  IdkWhatToCallThis[old_pos.x,old_pos.y,Action_taken]:=newStateActionValue;
end;

Function game_end(pos:tState):Boolean;
Begin
  //check if won
  If (pos.x = 3) and (pos.y = 0) then
    Begin
      Result:=true;
      Successes:=successes+1;
      writeln('won');
    end
  //or if lost
  Else If (pos.x = 3) and (pos.y = 1) then
    Begin
      result:=true;
      Failures:=Failures+1;
      writeln('lost');
    end
  //ansonsten weitermachen
  else result:=false;
end;

Procedure Move;
Var decision:BYTE;
Var Old_robbi:tState;
Begin

  //vorherige position von robbi speichern
  Old_robbi.x:=Robbi.x;
  old_robbi.y:=Robbi.y;

  //    Explore/Exploit
  If Random(100)+1 < Epsilon then Begin
      //random move
      decision:=random(anzActions)+1;
      Writeln('random');
      end
    else
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
 If game_end(Robbi) then
   Begin
     start_over;
   end;
 //wins and losses anzeigen
  Form1.Label_successes.caption:= inttostr(successes);
  Form1.Label_failiures.caption:= inttostr(Failures);
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
       IdkWhatToCallThis[x,y,a] := 0.0;
     begin
     end; // for action
   end; // for y
 end; // for x
end;

//===================================================================
//               Ereignisbehandlungsroutinen (EBR)
//-------------------------------------------------------------------

{ TForm1 }

procedure TForm1.FormCreate(Sender: TObject);
begin
  Form1.Timer_Move.Enabled:=false;
  Form1.Timer_Move.Interval:= 10;
  Start_Runs:=52;
  Successes:=0;
  Failures:=0;
  initBattleField();
  ///Discount:=0.9;


  start_over;
  update_robbi;
end;

procedure TForm1.Button_startClick(Sender: TObject);
begin
  Runs:=Start_Runs;
  Form1.Timer_Move.Enabled:=TRUE;
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
    For i:=1 to 1 DO Begin
    Move;
    Form1.Label_runs.caption:=IntToStr(Runs);
    Form1.Refresh;
    End
  end
  else Form1.Timer_Move.Enabled:=False;
end;

END.
