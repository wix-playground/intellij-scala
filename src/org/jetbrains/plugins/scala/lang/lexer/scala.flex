package org.jetbrains.plugins.scala.lang.lexer;

import com.intellij.lexer.FlexLexer;
import com.intellij.psi.tree.IElementType;
import java.util.*;
import java.lang.reflect.Field;
import org.jetbrains.annotations.NotNull;

%%

%class _ScalaLexer
%implements FlexLexer, ScalaTokenTypes
%unicode
%public

%function advance
%type IElementType

%eof{ return;
%eof}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////// USER CODE //////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

%{
    // Length of NewLine token
    private Stack <IElementType> braceStack = new Stack<IElementType>();

    /* Defines, is in this section new line is whitespace or not? */
    private boolean newLineAllowed(){
      if (braceStack.isEmpty()){
        return true;
      } else {
        if (ScalaTokenTypes.tLBRACE.equals(braceStack.peek())){
          return true;
        } else {
          return false;
        }
      }
    }

    /* Changes state depending on brace stack */
    private void changeState(){
      if (braceStack.isEmpty()) {
        yybegin(YYINITIAL);
      } else if ( tLPARENTHIS.equals(braceStack.peek()) || tLSQBRACKET.equals(braceStack.peek()) ){
        yybegin(NEW_LINE_DEPRECATED);
      } else {
        yybegin(NEW_LINE_ALLOWED);
      }
    }


    /* removes brace from stack */
    private IElementType popBraceStack(IElementType elem){
     if (
          !braceStack.isEmpty() &&
          (
            (elem.equals(tRSQBRACKET) && tLSQBRACKET.equals(braceStack.peek())) ||
            (elem.equals(tRBRACE) && tLBRACE.equals(braceStack.peek())) ||
            (elem.equals(tRPARENTHIS) && tLPARENTHIS.equals(braceStack.peek()))
          )
        ) {
          braceStack.pop();
          return process(elem);
        } else if (elem.equals(tFUNTYPE)) {
          if (!braceStack.isEmpty() && kCASE.equals(braceStack.peek())) {
            braceStack.pop();
          }
          return process(elem);
        } else {
          return tWRONG;
        }
    }

    private IElementType process(IElementType type){
        return type;
    }

    private void processNewLine(){
      yybegin(PROCESS_NEW_LINE);
    }

%}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////      integers and floats     /////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

integerLiteral = ({decimalNumeral} | {hexNumeral} | {octalNumeral}) (L | l)?
decimalNumeral = 0 | {nonZeroDigit} {digit}*
hexNumeral = 0 x {hexDigit}+
octalNumeral = 0{octalDigit}+
digit = [0-9]
nonZeroDigit = [1-9]
octalDigit = [0-7]
hexDigit = [0-9A-Fa-f]

floatingPointLiteral =
        {digit}+ "." {digit}* {exponentPart}? {floatType}?
    | "." {digit}+ {exponentPart}? {floatType}?
    | {digit}+ {exponentPart} {floatType}?
    | {digit}+ {exponentPart}? {floatType}
exponentPart = (E | e) ("+" | "-")? {digit}+
floatType = F | f | D | d

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////      identifiers      ////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

identifier = {plainid} //| "'" "\"" {stringLiteral} "\"" "'"

digit = [0-9]
special =   \u0021 | \u0023
          | [\u0025-\u0026]
          | [\u002A-\u002B]
          | \u002D | \u005E
          | \u003A
          | [\u003C-\u0040]
          | \u007E
          | \u005C | \u002F     //slashes

// Vertical line haemorrhoids
op = \u007C ({special} | \u007C)+
     | {special} ({special} | \u007C)*

idrest1 = [:jletter:]? [:jletterdigit:]* ("_" {op})?
idrest = [:jletter:]? [:jletterdigit:]* ("_" {op} | "_" {idrest1} )?
varid = [:jletter:] {idrest}

plainid = {varid}
          | {op}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////// String & chars //////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


CHARACTER_LITERAL="'"([^\\\'\r\n]|{ESCAPE_SEQUENCE})*("'"|\\)?
STRING_LITERAL=\"([^\\\"\r\n]|{ESCAPE_SEQUENCE})*(\"|\\)?

charEscapeSeq = \\[^\r\n]
charNoDoubleQuote = !( ![^"\""] | {LineTerminator})
stringElement = {charNoDoubleQuote} | {charEscapeSeq}
stringLiteral = {stringElement}*
characterLiteral = "\'" {charEscapeSeq} "\'"
                   | "\'" [^"\'"] "\'"
symbolLiteral = "\'" {plainid}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////// NewLine processing ///////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

notFollowNewLine =   "catch" | "else" | "extends" | "finally" | "match" | "requires" | "with" | "yield"
                    | "," | "." | ";" | ":" | "_" | "=" | "=>" | "<-" | "<:" | "<%" | ">:"
                    | "#" | "@" | ")" | "]" |"}"

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////// Common symbols //////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

LineTerminator = \r | \n | \r\n | \u0085|  \u2028 | \u2029
InLineTerminator = " " | "\t" | "\f"
WhiteSpaceInLine = {InLineTerminator}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////  xml tag  /////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

openXmlBracket = "<"
closeXmlBracket = ">"

openXmlTag = {openXmlBracket} {stringLiteral} {closeXmlBracket}
closeXmlTag = {openXmlBracket} "\\" {stringLiteral} {closeXmlBracket}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////  states ///////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

%state NEW_LINE_DEPRECATED
%state NEW_LINE_ALLOWED

%xstate PROCESS_NEW_LINE
// Valid preceding token for newlinw encountered

//%state IN_BLOCK_COMMENT_STATE
// In block comment

%xstate IN_STRING_STATE
// Inside the string... Boo!

%xstate IN_XML_STATE
//the scala expression between xml tags
%%


<YYINITIAL>{
"]"                                     {   processNewLine();
                                            return process(tRSQBRACKET); }

"}"                                     {   processNewLine();
                                            return process(tRBRACE); }

")"                                     {   processNewLine();
                                            return process(tRPARENTHIS); }
"=>"                                    {   return process(tFUNTYPE);  }
                                               
}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////  New line processing state////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
<PROCESS_NEW_LINE>{

{WhiteSpaceInLine}                              { return process(tWHITE_SPACE_IN_LINE);  }
"//" .*                                         { return process(tCOMMENT); }

{LineTerminator} / (" ")* {notFollowNewLine} {identifier}
                                                {   changeState();
                                                    if(newLineAllowed()){
                                                      return process(tLINE_TERMINATOR);
                                                    } else {
                                                      return process(tNON_SIGNIFICANT_NEWLINE);
                                                    }
                                                }


{LineTerminator} / (" ")* {notFollowNewLine}    {   changeState();
                                                    return process(tNON_SIGNIFICANT_NEWLINE);
                                                }


{LineTerminator}/ (.|{LineTerminator})          {   changeState();
                                                    if(newLineAllowed()){
                                                      return process(tLINE_TERMINATOR);
                                                    } else {
                                                      return process(tNON_SIGNIFICANT_NEWLINE);
                                                    }
                                                }

{LineTerminator}                                {   changeState();
                                                    return process(tLINE_TERMINATOR);
                                                }

.                                               {   yypushback(yylength());
                                                    changeState();
                                                }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////// In block comment /////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//<IN_BLOCK_COMMENT_STATE>{
//
//"*/"                                    {   yybegin(YYINITIAL);
//                                            return process(tCOMMENT);
//                                        }

//.|{LineTerminator}                      {   return process(tCOMMENT); }

//}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////// Inside a string  /////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
<IN_STRING_STATE>{

"\"" {stringLiteral}* "\""              {   yybegin(PROCESS_NEW_LINE);
                                            return process(tSTRING);
                                        }

("\"" {stringLiteral}*) / {LineTerminator}            {   yybegin(PROCESS_NEW_LINE);
                                                          return process(tWRONG_STRING);
                                                      }

.                                       {   return process(tSTUB); }

}

//todo: it is nesseccary organize stack of statements to control opened and corresponding closed tags
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////// Inside a xml  /////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
<IN_XML_STATE>{

"{"                                     {   yybegin(YYINITIAL);
                                            return process(tBEGINSCALAEXPR);
                                        }

"}"                                     {   yybegin(IN_XML_STATE);
                                            return process(tENDSCALAEXPR);
                                        }

{openXmlTag}                            {   yybegin(IN_XML_STATE);
                                            return process(tOPENXMLTAG);
                                        }

{closeXmlTag}                           {   yybegin(YYINITIAL);
                                            return process(tCLOSEXMLTAG);
                                        }

.|{LineTerminator}                      {   return process(tSTRING); }

}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////// FOR ALL INCLUSIVE STATES //////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////// comments ///////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

"//" .*                                    { return process(tCOMMENT); }


//"/*" {special}*                           {   yybegin(IN_BLOCK_COMMENT_STATE);
//                                              return process(tCOMMENT);
//                                          }


"/*" {special}* ~ "*/"                      {   return process(tCOMMENT); }




////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////// Strings /////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//{wholeString}                         {   processNewLine();
//                                          return process(tSTRING);  }

"\""                                    {   yypushback(yylength());
                                            yybegin(IN_STRING_STATE);
                                        }

{characterLiteral}                      {   processNewLine();
                                            return process(tCHAR);  }

{symbolLiteral}                         {   processNewLine();
                                            return process(tSYMBOL);  }

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////// braces ///////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
"["                                     {   braceStack.push(tLSQBRACKET);
                                            yybegin(NEW_LINE_DEPRECATED);
                                            return process(tLSQBRACKET); }
"]"                                     {   processNewLine();
                                            return popBraceStack(tRSQBRACKET); }

"{"                                     {   braceStack.push(tLBRACE);
                                            yybegin(NEW_LINE_ALLOWED);
                                            return process(tLBRACE); }
"}"                                     {   processNewLine();
                                            return popBraceStack(tRBRACE); }

"("                                     {   braceStack.push(tLPARENTHIS);
                                            yybegin(NEW_LINE_DEPRECATED);
                                            return process(tLPARENTHIS); }
")"                                     {   processNewLine();
                                            return popBraceStack(tRPARENTHIS); }
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////// keywords /////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

"abstract"                              {   return process(kABSTRACT); } 

"case" / ({LineTerminator}|" ")+ ("class" | "object")
                                        {   return process(kCASE); }

"case"                                  {   braceStack.push(kCASE);
                                            yybegin(NEW_LINE_DEPRECATED);
                                            return process(kCASE); }
                                            
"catch"                                 {   return process(kCATCH); }
"class"                                 {   return process(kCLASS); }
"def"                                   {   return process(kDEF); }
"do"                                    {   return process(kDO); }
"else"                                  {   return process(kELSE); }
"extends"                               {   return process(kEXTENDS); }
"false"                                 {   processNewLine();
                                            return process(kFALSE); }
"final"                                 {   return process(kFINAL); }
"finally"                               {   return process(kFINALLY); }
"for"                                   {   return process(kFOR); }
"if"                                    {   return process(kIF); }
"implicit"                              {   return process(kIMPLICIT); }
"import"                                {   return process(kIMPORT); }
"match"                                 {   return process(kMATCH); }
"new"                                   {   return process(kNEW); }
"null"                                  {   processNewLine();
                                            return process(kNULL); }
"object"                                {   return process(kOBJECT); }
"override"                              {   return process(kOVERRIDE); }
"package"                               {   return process(kPACKAGE); }
"private"                               {   return process(kPRIVATE); }
"protected"                             {   return process(kPROTECTED); }
"requires"                              {   return process(kREQUIRES); }
"return"                                {   processNewLine();
                                            return process(kRETURN); }
"sealed"                                {   return process(kSEALED); }
"super"                                 {   return process(kSUPER); }
"this"                                  {   processNewLine();
                                            return process(kTHIS); }
"throw"                                 {   return process(kTHROW); }
"trait"                                 {   return process(kTRAIT); }
"try"                                   {   return process(kTRY); }
"true"                                  {   processNewLine();
                                            return process(kTRUE); }
"type"                                  {   return process(kTYPE); }
"val"                                   {   return process(kVAL); }
"var"                                   {   return process(kVAR); }
"while"                                 {   return process(kWHILE); }
"with"                                  {   return process(kWITH); }
"yield"                                 {   return process(kYIELD); }

///////////////////// Reserved shorthands //////////////////////////////////////////
"*"                                     {   return process(tSTAR);  }
"?"                                     {   return process(tQUESTION);  }
"_"                                     {   processNewLine();
                                            return process(tUNDER);  }
":"                                     {   return process(tCOLON);  }
"="                                     {   return process(tASSIGN);  }
"=>"                                    {   return popBraceStack(tFUNTYPE); }
\u21D2                                  {   return process(tFUNTYPE_ASCII); }
"<-"                                    {   return process(tCHOOSE); }
"<:"                                    {   return process(tLOWER_BOUND); }
">:"                                    {   return process(tUPPER_BOUND); }
"<%"                                    {   return process(tVIEW); }
"#"                                     {   return process(tINNER_CLASS); }
"@"                                     {   return process(tAT);}
"&"                                     {   return process(tAND);}
"|"                                     {   return process(tOR);}

"+"                                     {   return process(tPLUS);}
"-"                                     {   return process(tMINUS);}
"~"                                     {   return process(tTILDA);}
"!"                                     {   return process(tNOT);}

"."                                     {   return process(tDOT);}
";"                                     {   return process(tSEMICOLON);}
","                                     {   return process(tCOMMA);}


////////////////////// Identifier /////////////////////////////////////////

{identifier}                            {   processNewLine();
                                            return process(tIDENTIFIER); }
{integerLiteral}                        {   processNewLine();
                                            return process(tINTEGER);  }
{floatingPointLiteral}                  {   processNewLine();
                                            return process(tFLOAT);      }

///////////////////// Operators //////////////////////////////////////////


////////////////////// XML /////////////////////////////////////////

//{openXmlTag}                                {   yybegin(IN_XML_STATE);
//                                            return process(tOPENXMLTAG); }

////////////////////// white spaces in line ///////////////////////////////////////////////
{WhiteSpaceInLine}                            {   return process(tWHITE_SPACE_IN_LINE);  }

////////////////////// white spaces line terminator ///////////////////////////////////////////////
{LineTerminator}                              {   return process(tNON_SIGNIFICANT_NEWLINE); }

////////////////////// STUB ///////////////////////////////////////////////
.                                             {   return process(tSTUB); }

