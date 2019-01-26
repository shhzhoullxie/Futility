!++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++!
!                          Futility Development Group                          !
!                             All rights reserved.                             !
!                                                                              !
! Futility is a jointly-maintained, open-source project between the University !
! of Michigan and Oak Ridge National Laboratory.  The copyright and license    !
! can be found in LICENSE.txt in the head directory of this repository.        !
!++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++!
!> @brief Utility module for parsing elements of an input text file into
!>        a parameter list based on a provided schema
!>
!> This package provides a parser which will read an input text file and
!> extract relevant information from said file based on a provided
!> schema and place it into a target parameterlist.  The parser will
!> also perform some light-weight error checking based on limits
!> specifications also provided in the schema.  This error checking will
!> be limited to what may be accomplished using the information
!> available from a single keyword-value pair.
!>
!> @par Module Dependencies
!>  - @ref IntrType "IntrType": @copybrief IntrType
!>  - @ref ExceptionHandler "ExceptionHandler": @copybrief ExceptionHandler
!>  - @ref IO_Strings "IO_Strings": @copybrief IO_Strings
!>
!> @author Cole Gentry
!>   @date 01/14/2019
!>
!++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++!
MODULE SchemaParser
#include "Futility_DBC.h"
  USE Futility_DBC
  USE IntrType
  USE Strings
  USE IO_Strings
  USE ExceptionHandler
  USE ParameterLists
  USE FileType_Input

  IMPLICIT NONE
  PRIVATE
!
! List of public members
  PUBLIC :: eSchemaParser
  PUBLIC :: SchemaParserType
  PUBLIC :: SINGLE_OCCURRENCE
  PUBLIC :: MULTPL_OCCURRENCE
  PUBLIC :: SCHEMA_ELEMENT_REQUIRED
  PUBLIC :: SCHEMA_ELEMENT_NOT_REQUIRED
  PUBLIC :: SIK_ENTRY
  PUBLIC :: SRK_ENTRY
  PUBLIC :: SBK_ENTRY
  PUBLIC :: STR_ENTRY
  PUBLIC :: SIKa1_ENTRY
  PUBLIC :: SRKa1_ENTRY
  PUBLIC :: SBKa1_ENTRY
  PUBLIC :: STRA1_ENTRY

  !> Enumerations for the BLOCK TYPES
  INTEGER(SIK),PARAMETER :: SINGLE_OCCURRENCE=1
  INTEGER(SIK),PARAMETER :: MULTPL_OCCURRENCE=2

  !> Aliasing of Element requirement
  LOGICAL(SBK),PARAMETER :: SCHEMA_ELEMENT_REQUIRED=.TRUE.
  LOGICAL(SBK),PARAMETER :: SCHEMA_ELEMENT_NOT_REQUIRED=.FALSE.

  !> Enumerations for the ENTRY TYPES
  INTEGER(SIK),PARAMETER :: SIK_ENTRY=1
  INTEGER(SIK),PARAMETER :: SRK_ENTRY=2
  INTEGER(SIK),PARAMETER :: SBK_ENTRY=3
  INTEGER(SIK),PARAMETER :: STR_ENTRY=4
  INTEGER(SIK),PARAMETER :: SIKa1_ENTRY=5
  INTEGER(SIK),PARAMETER :: SRKa1_ENTRY=6
  INTEGER(SIK),PARAMETER :: SBKa1_ENTRY=7
  INTEGER(SIK),PARAMETER :: STRA1_ENTRY=8

  !> Enumeration for undefined status
  INTEGER(SIK),PARAMETER :: UNDEFINED_TYPE=-1

  !> Enumeration for undefined element
  INTEGER(SIK),PARAMETER :: UNDEFINED_ELEMENT=-1

  !> Name of module
  CHARACTER(LEN=*),PARAMETER :: modName='SCHEMA_PARSER'

  !> Max allowed lengths for text file reading
  INTEGER(SIK),PARAMETER :: MAX_ELEMENT_NAME_LEN = 20
  INTEGER(SIK),PARAMETER :: MAX_LINE_LEN = 5000

  !> Base Entry Type
  TYPE,ABSTRACT :: SchemaEntryType
    !> the Parameter List to write the entry data to
    TYPE(StringType),PRIVATE :: pListPath
!
!List of type bound procedures
    CONTAINS
      !> @copybrief SchemaCardType::addPLPath_SchEnt
      !> @copydetails SchemaCardType::addPLPath_SchEnt
      PROCEDURE,PASS :: addPLPath => addPLPath_SchEnt
      !> @copybrief SchemaEntryType::parse_SchEnt_absintfc
      !> @copydetails SchemaEntryType::parse_SchEnt_absintfc
      PROCEDURE(parse_SchEnt_absintfc),DEFERRED,PASS :: parse
  ENDTYPE SchemaEntryType

  !> Type that is a container so as to have an array of pointers of
  !> Entry types
  TYPE :: SchemaEntryPtrArryType
    !> Polymorphic pointer array of assemblies
    CLASS(SchemaEntryType),POINTER :: entryPtr => NULL()
  ENDTYPE SchemaEntryPtrArryType

  !> SIK Entry Type
  TYPE,EXTENDS(SchemaEntryType) :: SchemaEntrySIKType
!List of type bound procedures
    CONTAINS
      !> @copybrief SchemaEntryType::parseSIK_SchEnt
      !> @copydetails SchemaEntryType::parseSIK_SchEnt
      PROCEDURE,PASS :: parse => parseSIK_SchEnt
  ENDTYPE SchemaEntrySIKType

  !> SRK Entry Type
  TYPE,EXTENDS(SchemaEntryType) :: SchemaEntrySRKType
!List of type bound procedures
    CONTAINS
      !> @copybrief SchemaEntryType::parseSRK_SchEnt
      !> @copydetails SchemaEntryType::parseSRK_SchEnt
      PROCEDURE,PASS :: parse => parseSRK_SchEnt
  ENDTYPE SchemaEntrySRKType

  !> SBK Entry Type
  TYPE,EXTENDS(SchemaEntryType) :: SchemaEntrySBKType
!List of type bound procedures
    CONTAINS
      !> @copybrief SchemaEntryType::parseSBK_SchEnt
      !> @copydetails SchemaEntryType::parseSBK_SchEnt
      PROCEDURE,PASS :: parse => parseSBK_SchEnt
  ENDTYPE SchemaEntrySBKType

  !> STR Entry Type
  TYPE,EXTENDS(SchemaEntryType) :: SchemaEntrySTRType
!List of type bound procedures
    CONTAINS
      !> @copybrief SchemaEntryType::parseSTR_SchEnt
      !> @copydetails SchemaEntryType::parseSTR_SchEnt
      PROCEDURE,PASS :: parse => parseSTR_SchEnt
  ENDTYPE SchemaEntrySTRType

  !> SIKa1 Entry Type
  TYPE,EXTENDS(SchemaEntryType) :: SchemaEntrySIKa1Type
!List of type bound procedures
    CONTAINS
      !> @copybrief SchemaEntryType::parseSIKa1_SchEnt
      !> @copydetails SchemaEntryType::parseSIKa1_SchEnt
      PROCEDURE,PASS :: parse => parseSIKa1_SchEnt
  ENDTYPE SchemaEntrySIKa1Type

  !> SRKa1 Entry Type
  TYPE,EXTENDS(SchemaEntryType) :: SchemaEntrySRKa1Type
!List of type bound procedures
    CONTAINS
      !> @copybrief SchemaEntryType::parseSRKa1_SchEnt
      !> @copydetails SchemaEntryType::parseSRKa1_SchEnt
      PROCEDURE,PASS :: parse => parseSRKa1_SchEnt
  ENDTYPE SchemaEntrySRKa1Type

  !> SBKa1 Entry Type
  TYPE,EXTENDS(SchemaEntryType) :: SchemaEntrySBKa1Type
!List of type bound procedures
    CONTAINS
      !> @copybrief SchemaEntryType::parseSBKa1_SchEnt
      !> @copydetails SchemaEntryType::parseSBKa1_SchEnt
      PROCEDURE,PASS :: parse => parseSBKa1_SchEnt
  ENDTYPE SchemaEntrySBKa1Type

  !> STRa1 Entry Type
  TYPE,EXTENDS(SchemaEntryType) :: SchemaEntrySTRa1Type
!List of type bound procedures
    CONTAINS
      !> @copybrief SchemaEntryType::parseSTRa1_SchEnt
      !> @copydetails SchemaEntryType::parseSTRa1_SchEnt
      PROCEDURE,PASS :: parse => parseSTRa1_SchEnt
  ENDTYPE SchemaEntrySTRa1Type

  !> Type that defines a Element of a schema
  TYPE :: SchemaElementType
    !> element name (as it should appear in the input file)
    TYPE(StringType),PRIVATE :: name
    !> the Parameter List to write the element data to
    TYPE(StringType),PRIVATE :: pListPath
    !> Occurence Type
    INTEGER(SIK),PRIVATE :: type=UNDEFINED_TYPE
    !> Whether or not the element is required
    LOGICAL(SBK),PRIVATE :: isRequired=.FALSE.
    !> Number of Elment Occurrences when reading input
    INTEGER(SIK),PRIVATE :: nOccurrences=0
    !> Starting lines for each Element Occurrence
    INTEGER(SIK),ALLOCATABLE,PRIVATE :: startLine(:)
    !> Stopping lines for each Element Occurrence
    INTEGER(SIK),ALLOCATABLE,PRIVATE :: stopLine(:)
    !> Starting field of the element within the starting line
    INTEGER(SIK),ALLOCATABLE,PRIVATE :: startField(:)
    !> Stopping field of the element within the stopping line
    INTEGER(SIK),ALLOCATABLE,PRIVATE :: stopField(:)
!
!List of type bound procedures
    CONTAINS
      !> @copybrief SchemaElementType::init_SchElm
      !> @copydetails SchemaElementType::init_SchElm
      PROCEDURE,PASS :: init => init_SchElm
      !> @copybrief SchemaCardType::hasName_SchElm
      !> @copydetails SchemaCardType::hasName_SchElm
      PROCEDURE,PASS :: hasName => hasName_SchElm
      !> @copybrief SchemaCardType::countOccurrences_SchElm
      !> @copydetails SchemaCardType::countOccurrences_SchElm
      PROCEDURE,PASS :: countOccurrences => countOccurrences_SchElm
      !> @copybrief SchemaCardType::nOccurrencesIsValid_SchElm
      !> @copydetails SchemaCardType::nOccurrencesIsValid_SchElm
      PROCEDURE,PASS :: nOccurrencesIsValid => nOccurrencesIsValid_SchElm
      !> @copybrief SchemaCardType::determineExtentsWithinTextFile_SchElm
      !> @copydetails SchemaCardType::determineExtentsWithinTextFile_SchElm
      PROCEDURE,PASS :: determineExtentsWithinTextFile => determineExtentsWithinTextFile_SchElm
      !> @copybrief SchemaCardType::addPLPath_SchElm
      !> @copydetails SchemaCardType::addPLPath_SchElm
      PROCEDURE,PASS :: addPLPath => addPLPath_SchElm
  ENDTYPE SchemaElementType

  !> Type that defines a card of a block
  TYPE,EXTENDS(SchemaElementType) :: SchemaCardType
    !> The cards defining this block
    TYPE(SchemaEntryPtrArryType),ALLOCATABLE,PRIVATE :: entry(:)
!
!List of type bound procedures
    CONTAINS
      !> @copybrief SchemaCardType::addEntry_SchCrd
      !> @copydetails SchemaCardType::addEntry_SchCrd
      PROCEDURE,PRIVATE,PASS :: addEntry => addEntry_SchCrd
      !> @copybrief SchemaCardType::addEntrySIK_SchCrd
      !> @copydetails SchemaCardType::addEntrySIK_SchCrd
      PROCEDURE,PASS :: addEntrySIK => addEntrySIK_SchCrd
      !> @copybrief SchemaCardType::addEntrySRK_SchCrd
      !> @copydetails SchemaCardType::addEntrySRK_SchCrd
      PROCEDURE,PASS :: addEntrySRK => addEntrySRK_SchCrd
      !> @copybrief SchemaCardType::addEntrySBK_SchCrd
      !> @copydetails SchemaCardType::addEntrySBK_SchCrd
      PROCEDURE,PASS :: addEntrySBK => addEntrySBK_SchCrd
      !> @copybrief SchemaCardType::addEntrySTR_SchCrd
      !> @copydetails SchemaCardType::addEntrySTR_SchCrd
      PROCEDURE,PASS :: addEntrySTR => addEntrySTR_SchCrd
      !> @copybrief SchemaCardType::addEntrySIKa1_SchCrd
      !> @copydetails SchemaCardType::addEntrySIKa1_SchCrd
      PROCEDURE,PASS :: addEntrySIKa1 => addEntrySIKa1_SchCrd
      !> @copybrief SchemaCardType::addEntrySRKa1_SchCrd
      !> @copydetails SchemaCardType::addEntrySRKa1_SchCrd
      PROCEDURE,PASS :: addEntrySRKa1 => addEntrySRKa1_SchCrd
      !> @copybrief SchemaCardType::addEntrySBKa1_SchCrd
      !> @copydetails SchemaCardType::addEntrySBKa1_SchCrd
      PROCEDURE,PASS :: addEntrySBKa1 => addEntrySBKa1_SchCrd
      !> @copybrief SchemaCardType::addEntrySTRa1_SchCrd
      !> @copydetails SchemaCardType::addEntrySTRa1_SchCrd
      PROCEDURE,PASS :: addEntrySTRa1 => addEntrySTRa1_SchCrd
      !> @copybrief SchemaCardType::clear_SchCrd
      !> @copydetails SchemaCardType::clear_SchCrd
      PROCEDURE,PASS :: clear => clear_SchCrd
      !> @copybrief SchemaCardType::parse_SchCrd
      !> @copydetails SchemaCardType::parse_SchCrd
      PROCEDURE,PASS :: parse => parse_SchCrd
  ENDTYPE SchemaCardType

  !> Type that defines a block of a schema
  TYPE,EXTENDS(SchemaElementType) :: SchemaBlockType
    !> The cards defining this block
    TYPE(SchemaCardType),ALLOCATABLE,PRIVATE :: card(:)
!
!List of type bound procedures
    CONTAINS
      !> @copybrief SchemaBlockType::addCard_SchBlk
      !> @copydetails SchemaBlockType::addCard_SchBlk
      PROCEDURE,PASS :: addCard => addCard_SchBlk
      !> @copybrief SchemaBlockType::addEntry_SchBlk
      !> @copydetails SchemaBlockType::addEntry_SchBlk
      PROCEDURE,PASS :: addEntry => addEntry_SchBlk
      !> @copybrief SchemaBlockType::clear_SchBlk
      !> @copydetails SchemaBlockType::clear_SchBlk
      PROCEDURE,PASS :: clear => clear_SchBlk
      !> @copybrief SchemaBlockType::parse_SchBlk
      !> @copydetails SchemaBlockType::parse_SchBlk
      PROCEDURE,PASS :: parse => parse_SchBlk

  ENDTYPE SchemaBlockType

  !> Type that contains a schema described by blocks and cards and uses
  !> this schema to parse a given input into a parameter list
  TYPE :: SchemaParserType
    !> Initialization status
    LOGICAL(SBK) :: isInit=.FALSE.
    !> The blocks defining this schema
    TYPE(SchemaBlockType),ALLOCATABLE,PRIVATE :: block(:)
!
!List of type bound procedures
    CONTAINS
      !>TODO:We could also add an init from parameter_list or external file type
      !> @copybrief SchemaParser::init_SchPar
      !> @copydetails SchemaParser::init_SchPar
      PROCEDURE,PASS :: init => init_SchPar
      !> @copybrief SchemaParser::clear_SchPar
      !> @copydetails SchemaParser::clear_SchPar
      PROCEDURE,PASS :: clear => clear_SchPar
      !> @copybrief SchemaParser::addBlock_SchPar
      !> @copydetails SchemaParser::addBlock_SchPar
      PROCEDURE,PASS :: addBlock => addBlock_SchPar
      !> @copybrief SchemaParser::addCard_SchPar
      !> @copydetails SchemaParser::addCard_SchPar
      PROCEDURE,PASS :: addCard => addCard_SchPar
      !> @copybrief SchemaParser::addEntry_SchPar
      !> @copydetails SchemaParser::addEntry_SchPar
      PROCEDURE,PASS :: addEntry => addEntry_SchPar
      !> @copybrief SchemaParser::parse_SchPar
      !> @copydetails SchemaParser::parse_SchPar
      PROCEDURE,PASS :: parse => parse_SchPar

  ENDTYPE SchemaParserType

  ABSTRACT INTERFACE
    SUBROUTINE parse_SchEnt_absintfc(this,entryStr,paramList,pListPathCrd)
      IMPORT :: SchemaEntryType,StringType,ParamType
      CLASS(SchemaEntryType),INTENT(IN) :: this
      CLASS(StringType),INTENT(IN) :: entryStr
      CLASS(ParamType),INTENT(INOUT) :: paramList
      TYPE(StringType),INTENT(IN) :: pListPathCrd
    ENDSUBROUTINE parse_SchEnt_absintfc
  ENDINTERFACE

  !> Exception Handler for use in SchemaParser
  TYPE(ExceptionHandlerType),SAVE :: eSchemaParser
!
!===============================================================================
  CONTAINS
!
!-------------------------------------------------------------------------------
!> @brief Constructor for the schema parser
!> @param this the variable to initialize
!>
!> The constructor for the schema parser
!>
    SUBROUTINE init_SchPar(this)
      CHARACTER(LEN=*),PARAMETER :: myName='init_SchPar'
      CLASS(SchemaParserType),INTENT(INOUT) :: this

      ALLOCATE(this%block(0))
      this%isInit=.TRUE.
    ENDSUBROUTINE init_SchPar
!
!-------------------------------------------------------------------------------
!> @brief Routine clears the data in Schema Parser type variable
!> @param this the type variable to clear
!>
    SUBROUTINE clear_SchPar(this)
      CLASS(SchemaParserType),INTENT(INOUT) :: this

      INTEGER(SIK) iblock,nBlocks

      REQUIRE(this%isInit)
      nBlocks=SIZE(this%block)
      DO iblock=1,nBlocks
        CALL this%block(iblock)%clear()
      ENDDO
      DEALLOCATE(this%block)
      this%isInit=.FALSE.
    ENDSUBROUTINE clear_SchPar
!
!-------------------------------------------------------------------------------
!> @brief initializes this schema element
!> @param this        the element to be initialized
!> @param name        the name of the element as it will appear in the input
!> @param pListPath   the parameter list path under which the element data will
!>                    put in the outgoing parameter list
!> @param type        occurence type, either single or multi occurrence
!> @param required    whether or not the element is required`
!>
    SUBROUTINE init_SchElm(this,name,pListPath,type,required)
      CLASS(SchemaElementType),INTENT(INOUT) :: this
      TYPE(StringType),INTENT(IN) :: name
      TYPE(StringType),INTENT(IN) :: pListPath
      INTEGER(SIK),INTENT(IN) :: type
      LOGICAL(SBK),INTENT(IN) :: required

      ! Create the element
      this%name = TRIM(name)
      this%pListPath = TRIM(pListPath)
      this%type = type
      this%isRequired = required
    ENDSUBROUTINE init_SchElm
!
!-------------------------------------------------------------------------------
!> @brief States whether or not the element has the provided name
!> @param this  the element whose name is to be checked
!> @param name  the name 
!>
    FUNCTION hasName_SchElm(this,name) RESULT(hasName)
      CLASS(SchemaElementType),INTENT(IN) :: this
      TYPE(StringType),INTENT(IN) :: name
      LOGICAL(SBK) :: hasName

      hasName=(TRIM(name)==TRIM(this%name))
    ENDFUNCTION hasName_SchElm
!
!-------------------------------------------------------------------------------
!> @brief Determines the number of times an element occurs in a given file
!> @param this      the element whose number of occurrences is to be determined
!> @param inputfile  the input file to be read
!> @param startLine  the first line within the file to start considering 
!> @param startLine  the last line within the file to start considering 
!> @param startField the first field within the start line to start considering 
!> @param stopField  the last field within the stop line to start considering 
!>
    SUBROUTINE countOccurrences_SchElm(this,inputFile,startLine,stopLine,startField,stopField)
      CLASS(SchemaElementType),INTENT(INOUT) :: this
      TYPE(InputFileType),INTENT(INOUT) :: inputFile
      INTEGER(SIK),INTENT(IN),OPTIONAL :: startLine
      INTEGER(SIK),INTENT(IN),OPTIONAL :: stopLine
      INTEGER(SIK),INTENT(IN),OPTIONAL :: startField
      INTEGER(SIK),INTENT(IN),OPTIONAL :: stopField

      TYPE(StringType) :: line,fieldStr
      INTEGER(SIK) :: iline,ifield
      INTEGER(SIK) :: sttLine,stpLine,sttField,stpField

      !Set the bounds on the text file being considered
      sttLine=0; sttField=0; stpLine=HUGE(1_SIK); stpField=HUGE(1_SIK)
      IF(PRESENT(startLine))   sttLine=startLine;  IF(PRESENT(stopLine))   stpLine=stopLine
      IF(PRESENT(startField)) sttField=startField; IF(PRESENT(stopField)) stpField=stopField

      iline=0
      this%nOccurrences=0
      DO WHILE(.NOT.atEndOfFile(inputFile))
        CALL inputfile%fgetl(line)
        iline=iline+1
        IF(iline>=sttLine .AND. iline<=stpLine) THEN
          IF(atContentLine(inputFile)) THEN
            DO ifield=1,nFields(line)
              IF((iline>sttLine .OR. ifield>=sttField) .AND. (iline<stpLine .OR. ifield<=stpField)) THEN
                CALL getField(ifield,line,fieldStr)
                IF(fieldStr==this%name) this%nOccurrences=this%nOccurrences+1
              ENDIF 
            ENDDO
          ENDIF
        ENDIF
      ENDDO
      CALL inputfile%frewind()
    ENDSUBROUTINE countOccurrences_SchElm
!
!-------------------------------------------------------------------------------
!> @brief Determines the starting and stopping lines and fields for each
!>        occurrence of the element within the given text file
!> @param this          the element whose extents are to be determined and set
!> @param inputfile     the input file to be read
!> @param validElements an array of the other valid elements
!> @param startLine  the first line within the file to start considering
!> @param startLine  the last line within the file to start considering
!> @param startField the first field within the start line to start considering
!> @param stopField  the last field within the stop line to start considering
!>
    SUBROUTINE determineExtentsWithinTextFile_SchElm(this,inputFile,validElements,startLine,stopLine,startField,stopField)
      CLASS(SchemaElementType),INTENT(INOUT) :: this
      TYPE(InputFileType),INTENT(INOUT) :: inputFile
      CLASS(SchemaElementType),INTENT(IN) :: validElements(:)
      INTEGER(SIK),INTENT(IN),OPTIONAL :: startLine
      INTEGER(SIK),INTENT(IN),OPTIONAL :: stopLine
      INTEGER(SIK),INTENT(IN),OPTIONAL :: startField
      INTEGER(SIK),INTENT(IN),OPTIONAL :: stopField

      TYPE(StringType) :: line,fieldStr
      INTEGER(SIK) :: ifield,ioccur,iline
      LOGICAL(SBK) :: readingThisElement
      INTEGER(SIK) :: sttLine,stpLine,sttField,stpField

      !Set the bounds on the text file being considered
      sttLine=0; sttField=0; stpLine=HUGE(1_SIK); stpField=HUGE(1_SIK)
      IF(PRESENT(startLine))   sttLine=startLine;  IF(PRESENT(stopLine))   stpLine=stopLine
      IF(PRESENT(startField)) sttField=startField; IF(PRESENT(stopField)) stpField=stopField

      IF(ALLOCATED(this%startLine))  DEALLOCATE(this%startLine);  ALLOCATE(this%startLine(this%nOccurrences))
      IF(ALLOCATED(this%stopLine))   DEALLOCATE(this%stopLine);   ALLOCATE(this%stopLine(this%nOccurrences))
      IF(ALLOCATED(this%startField)) DEALLOCATE(this%startField); ALLOCATE(this%startField(this%nOccurrences))
      IF(ALLOCATED(this%stopField))  DEALLOCATE(this%stopField);  ALLOCATE(this%stopField(this%nOccurrences))

      ioccur=0
      iline=0
      readingThisElement=.FALSE.
      DO WHILE(.NOT.atEndOfFile(inputFile))
        CALL inputfile%fgetl(line)
        iline=iline+1
        IF(iline>stpLine) EXIT
        IF(iline>=sttLine) THEN
          IF(atContentLine(inputFile)) THEN
            DO ifield=1,nFields(line)
              IF((iline==stpLine .AND. ifield>stpField)) EXIT
              IF(iline>sttLine .OR. ifield>=sttField) THEN
                CALL getField(ifield,line,fieldStr)
                IF(fieldStr==this%name) THEN
                  ioccur=ioccur+1
                  this%startLine(ioccur)=iline
                  this%stopLine(ioccur)=iline
                  this%startField(ioccur)=ifield
                  this%stopField(ioccur)=ifield
                  readingThisElement=.TRUE.
                ELSEIF(ANY(fieldStr==validElements(:)%name)) THEN
                  readingThisElement=.FALSE.
                ENDIF
              ENDIF
              IF(readingThisElement) this%stopField(ioccur)=ifield
            ENDDO
          ENDIF
        ENDIF
        IF(readingThisElement) this%stopLine(ioccur)=iline
      ENDDO
      CALL inputfile%frewind()
    ENDSUBROUTINE determineExtentsWithinTextFile_SchElm
!
!-------------------------------------------------------------------------------
!> @brief Checks to see if a provided integer (i.e. the element occurrence 
!>        count) represents a valid occurrence count for this element and throws
!>        an error if not
!> @param this    the element whose count occurrence to check
!> @param isValid a logical indicating whether or not the occurrence count is
!>                valid
!>
    FUNCTION nOccurrencesIsValid_SchElm(this) RESULT(isValid)
      CHARACTER(LEN=*),PARAMETER :: myName='nOccurrencesIsValid_SchElm'
      CLASS(SchemaElementType),INTENT(IN) :: this
      LOGICAL(SBK) :: isValid

      isValid=.TRUE.
      IF(this%nOccurrences==0 .AND. this%isRequired) THEN
        CALL eSchemaParser%raiseError(modName//'::'//myName//' - "'// TRIM(this%name)//' Not Defined!') 
        isValid=.FALSE.
      ELSEIF(this%nOccurrences>1 .AND. this%type==SINGLE_OCCURRENCE) THEN
        CALL eSchemaParser%raiseError(modName//'::'//myName//' - "'// TRIM(this%name)//' Defined more than once!') 
        isValid=.FALSE.
      ENDIF
    ENDFUNCTION nOccurrencesIsValid_SchElm
!
!-------------------------------------------------------------------------------
!> @brief Appends the give pListPath with the element path
!> @param this      the element whose pListPath will be appended to the input 
!>                  pListPath
!> @param pListPath the pListPath to append the element pListPath to
!> @param ioccur    the occurrence number to be included in the pListPath
!>                  if this element type is a multiple occurrence type
!>
    SUBROUTINE addPLPath_SchElm(this,pListPath,ioccur)
      CLASS(SchemaElementType),INTENT(IN) :: this
      TYPE(StringType),INTENT(INOUT) ::pListPath
      INTEGER(SIK),INTENT(IN) :: ioccur

      CHARACTER(LEN=1000) ioccurChr

      IF(this%type==SINGLE_OCCURRENCE) THEN
        pListPath=pListPath//this%pListPath//'->'
      ELSE
        WRITE(ioccurChr,'(I0)') ioccur
        pListPath=pListPath//this%pListPath//'_'//TRIM(ioccurChr)//'->'
      ENDIF
    ENDSUBROUTINE addPLPath_SchElm
!
!-------------------------------------------------------------------------------
!> @brief Adds an empty block to the schema
!> @param this        the schema parser to add the block to
!> @param blockName   the name of the block as it will appear in the input
!> @param type        occurence type, either single or multi occurrence
!> @param required    whether or not the block is required`
!> @param pListPath   the parameter list path under which the block data will
!>                    put in the outgoing parameter list
!>
    SUBROUTINE addBlock_SchPar(this,blockName,type,required,pListPath)
      CLASS(SchemaParserType),INTENT(INOUT) :: this
      CHARACTER(LEN=*),INTENT(IN) :: blockName
      INTEGER(SIK),INTENT(IN) :: type
      LOGICAL(SBK),INTENT(IN) :: required
      CHARACTER(LEN=*),INTENT(IN),OPTIONAL :: pListPath

      TYPE(StringType) :: blockNameStr,pListPathStr
      TYPE(SchemaBlockType) :: block
      TYPE(SchemaBlockType),ALLOCATABLE :: prevblocks(:)
      INTEGER(SIK) :: iblock,nBlocks

      ! Initialize the block
      blockNameStr=TRIM(blockName)
      pListPathStr=TRIM(blockName)
      IF(PRESENT(pListPath)) pListPathStr=TRIM(pListPath)
      CALL block%init(blockNameStr,pListPathStr,type,required)
      ALLOCATE(block%card(0))

      ! Append this block to the list of blocks
      nBlocks=SIZE(this%block)
      ALLOCATE(prevblocks(nBlocks))
      prevblocks=this%block
      DEALLOCATE(this%block)
      ALLOCATE(this%block(nBlocks+1))
      DO iblock=1,nBlocks
        this%block(iblock)=prevblocks(iblock)
      ENDDO
      this%block(nBlocks+1)=block
    ENDSUBROUTINE addBlock_SchPar
!
!-------------------------------------------------------------------------------
!> @brief Adds an empty card to the schema under the specified block
!> @param this        the schema parser to add the card to
!> @param blockName   the name of the block to add the card to
!> @param cardName    the name of the card as it will appear in the input
!> @param type        occurence type, either single or multi occurrence
!> @param required    whether or not the block is required`
!> @param pListPath   the parameter list path under which the card data will be
!>                    put in the outgoing parameter list
!>
    SUBROUTINE addCard_SchPar(this,blockName,cardName,type,required,pListPath)
      CLASS(SchemaParserType),INTENT(INOUT) :: this
      CHARACTER(LEN=*),INTENT(IN) :: blockName
      CHARACTER(LEN=*),INTENT(IN) :: cardName
      INTEGER(SIK),INTENT(IN) :: type
      LOGICAL(SBK),INTENT(IN) :: required
      CHARACTER(LEN=*),INTENT(IN),OPTIONAL :: pListPath

      TYPE(StringType) :: cardNameStr,blockNameStr,pListPathStr
      INTEGER(SIK) :: iblock

      !Add the card to the block
      blockNameStr=TRIM(blockName)
      cardNameStr=TRIM(cardName)
      pListPathStr=TRIM(cardName)
      iblock=findElementByName(this%block,blockNameStr)
      REQUIRE(iblock/=UNDEFINED_ELEMENT)
      IF(PRESENT(pListPath)) pListPathStr=TRIM(pListPath)
      CALL this%block(iblock)%addCard(cardNameStr,pListPathStr,type,required)

    ENDSUBROUTINE addCard_SchPar
!
!-------------------------------------------------------------------------------
!> @brief Adds an entry to the schema under the specified block and card
!> @param this        the schema parser to add the entry to
!> @param blockName   the name of the block to add the entry to
!> @param cardName    the name of the card to add the entry to
!> @param type        occurence type, either single or multi occ
!> @param pListPath   the parameter list path under which the entry data will be
!>                    put in the outgoing parameter list
!>
    SUBROUTINE addEntry_SchPar(this,blockName,cardName,type,pListPath)
      CLASS(SchemaParserType),INTENT(INOUT) :: this
      CHARACTER(LEN=*),INTENT(IN) :: blockName
      CHARACTER(LEN=*),INTENT(IN) :: cardName
      INTEGER(SIK),INTENT(IN) :: type
      CHARACTER(LEN=*),INTENT(IN),OPTIONAL :: pListPath

      TYPE(StringType) :: cardNameStr,blockNameStr,pListPathStr
      INTEGER(SIK) :: iblock

      !Add the entry to the block
      blockNameStr=TRIM(blockName)
      cardNameStr=TRIM(cardName)
      iblock=findElementByName(this%block,blockNameStr)
      REQUIRE(iblock/=UNDEFINED_ELEMENT)
      IF(PRESENT(pListPath)) THEN
        pListPathStr=TRIM(pListPath)
      ELSE
        pListPathStr=''
      ENDIF
      CALL this%block(iblock)%addEntry(cardNameStr,pListPathStr,type)

    ENDSUBROUTINE addEntry_SchPar
!
!-------------------------------------------------------------------------------
!> @brief Parsing routine for the given input file and schema
!> @param this       the schema parser to perform parsing
!> @param inputFile  the input file to be parsed
!> @param paramList  the target parameter list in which to put the parsed data
!>
    SUBROUTINE parse_SchPar(this,inputFile,paramList)
      CHARACTER(LEN=*),PARAMETER :: myName='parse_SchPar'
      CLASS(SchemaParserType),INTENT(INOUT) :: this
      TYPE(InputFileType),INTENT(INOUT) :: inputFile
      TYPE(ParamType),INTENT(INOUT) :: paramList

      TYPE(StringType) line
      CHARACTER(LEN=6) :: limit
      INTEGER(SIK) :: iblock,ioccur
      
      REQUIRE(this%isInit)
      REQUIRE(inputFile%isOpen())

      !Ensure no line in the input file exceeds the max line limit
      DO WHILE(.NOT.atEndOfFile(inputFile))
        CALL inputfile%fgetl(line)
        IF(atContentLine(inputFile)) THEN
          IF(LEN(line)>MAX_LINE_LEN) THEN
            WRITE(limit,'(I0)') MAX_LINE_LEN
            CALL eSchemaParser%raiseError(modName//'::'//myName// &
              ' - "A content line exceeds the max line limit of '//limit//' characters')
            RETURN
          ENDIF
        ENDIF
      ENDDO
      CALL inputfile%frewind()

      !Parse each block
      DO iblock=1,SIZE(this%block)
        CALL this%block(iblock)%countOccurrences(inputFile)
        IF(.NOT.this%block(iblock)%nOccurrencesIsValid()) RETURN
        CALL this%block(iblock)%determineExtentsWithinTextFile(inputFile,this%block)
        DO ioccur=1,this%block(iblock)%nOccurrences
          CALL this%block(iblock)%parse(inputFile,paramList,ioccur)
        ENDDO
      ENDDO
    ENDSUBROUTINE parse_SchPar
!
!-------------------------------------------------------------------------------
!> @brief Adds an empty card to the block
!> @param this        the block to add the card to
!> @param name        the name of the card as it will appear in the input
!> @param pListPath  the parameter list path under which the card data will
!>                    put in the outgoing parameter list
!> @param type        occurence type, either single or multi occurrence
!> @param required    whether or not the card is required`
!>
    SUBROUTINE addCard_SchBlk(this,name,pListPath,type,required)
      CLASS(SchemaBlockType),INTENT(INOUT) :: this
      TYPE(StringType),INTENT(IN) :: name
      TYPE(StringType),INTENT(IN) :: pListPath
      INTEGER(SIK),INTENT(IN) :: type
      LOGICAL(SBK),INTENT(IN) :: required


      TYPE(SchemaCardType) :: card
      TYPE(SchemaCardType),ALLOCATABLE :: prevcards(:)
      INTEGER(SIK) :: icard,nCards

      ! Initialize the card
      CALL card%init(name,pListPath,type,required)
      ALLOCATE(card%entry(0))

      ! Append this card to the list of cards
      nCards=SIZE(this%card)
      ALLOCATE(prevcards(nCards))
      prevcards=this%card
      DEALLOCATE(this%card)
      ALLOCATE(this%card(nCards+1))
      DO icard=1,nCards
        this%card(icard)=prevcards(icard)
      ENDDO
      this%card(nCards+1)=card
    ENDSUBROUTINE addCard_SchBlk
!
!-------------------------------------------------------------------------------
!> @brief Adds an entry to the schema under the specified block and card
!> @param this        the schema parser to add the entry to
!> @param cardName    the name of the card to add the entry to
!> @param pListPath   the parameter list path under which the entry data will be
!>                    put in the outgoing parameter list
!> @param type        occurence type, either single or multi occ
!>
    SUBROUTINE addEntry_SchBlk(this,cardName,pListPath,type)
      CLASS(SchemaBlockType),INTENT(INOUT) :: this
      TYPE(StringType),INTENT(IN) :: cardName
      TYPE(StringType),INTENT(IN) :: pListPath
      INTEGER(SIK),INTENT(IN) :: type

      LOGICAL(SBK),PARAMETER :: isAnAcceptableEntryType=.FALSE.
      INTEGER(SIK) :: icard

      !Add the entry to the card
      icard=findElementByName(this%card,cardName)
      REQUIRE(icard/=UNDEFINED_ELEMENT)
      SELECTCASE(type)
        CASE(SIK_ENTRY);  CALL this%card(icard)%addEntrySIK(pListPath)
        CASE(SRK_ENTRY);  CALL this%card(icard)%addEntrySRK(pListPath)
        CASE(SBK_ENTRY);  CALL this%card(icard)%addEntrySBK(pListPath)
        CASE(STR_ENTRY);  CALL this%card(icard)%addEntrySTR(pListPath)
        CASE(SIKA1_ENTRY);  CALL this%card(icard)%addEntrySIKa1(pListPath)
        CASE(SRKA1_ENTRY);  CALL this%card(icard)%addEntrySRKa1(pListPath)
        CASE(SBKA1_ENTRY);  CALL this%card(icard)%addEntrySBKa1(pListPath)
        CASE(STRA1_ENTRY);  CALL this%card(icard)%addEntrySTRa1(pListPath)
        CASE DEFAULT;     REQUIRE(isAnAcceptableEntryType);
      ENDSELECT

    ENDSUBROUTINE addEntry_SchBlk
!
!-------------------------------------------------------------------------------
!> @brief Routine clears the data in Schema Block type variable
!> @param this the type variable to clear
!>
    SUBROUTINE clear_SchBlk(this)
      CLASS(SchemaBlockType),INTENT(INOUT) :: this

      INTEGER(SIK) icard,nCards

      nCards=SIZE(this%card)
      DO icard=1,nCards
        CALL this%card(icard)%clear()
      ENDDO
      DEALLOCATE(this%card)
    ENDSUBROUTINE clear_SchBlk
!
!-------------------------------------------------------------------------------
!> @brief Parsing routine for the given input file and block
!> @param this       the block to perform parsing
!> @param inputFile  the input file to be parsed
!> @param paramList  the target parameter list in which to put the parsed data
!> @param ioccurBlk  an integer representing the block occurrence being
!>                   considered
!>
    SUBROUTINE parse_SchBlk(this,inputFile,paramList,ioccurBlk)
      CHARACTER(LEN=*),PARAMETER :: myName='parse_SchBlk'
      CLASS(SchemaBlockType),INTENT(INOUT) :: this
      TYPE(InputFileType),INTENT(INOUT) :: inputFile
      TYPE(ParamType),INTENT(INOUT) :: paramList
      INTEGER(SIK),INTENT(IN) :: ioccurBlk

      INTEGER(SIK) :: nerr
      INTEGER(SIK) :: icard,ioccur,startLine,stopLine,startField,stopField
      TYPE(StringType) :: pListPath
      
      nerr=eSchemaParser%getCounter(EXCEPTION_ERROR)

      startLine=this%startLine(ioccurBlk); stopLine=this%stopLine(ioccurBlk);
      startField=this%startField(ioccurBlk); stopField=this%stopField(ioccurBlk);
      pListPath=''
      CALL this%addPLPath(pListPath,ioccurBlk)

      !Parse each Card
      DO icard=1,SIZE(this%card)
        CALL this%card(icard)%countOccurrences(inputFile,startLine,stopLine,startField,stopField)
        IF(.NOT.this%card(icard)%nOccurrencesIsValid()) RETURN
        CALL this%card(icard)%determineExtentsWithinTextFile(inputFile,this%card,startLine,stopLine,startField,stopField)
        DO ioccur=1,this%card(icard)%nOccurrences
          CALL this%card(icard)%parse(inputFile,paramList,ioccur,pListPath)
        ENDDO
      ENDDO

      IF(eSchemaParser%getCounter(EXCEPTION_ERROR) > nerr) THEN
        CALL eSchemaParser%raiseError(modName//'::'//myName//' - Error parsing block '//TRIM(this%name)//'!')
      ENDIF
    ENDSUBROUTINE parse_SchBlk
!
!-------------------------------------------------------------------------------
!> @brief Appends the entry to the list of entries owned by the card
!> @param this    the card to add the entry to
!> @param entry   the pointer to the entry to be added
!>
    SUBROUTINE addEntry_SchCrd(this,entry)
      CLASS(SchemaCardType),INTENT(INOUT) :: this
      TYPE(SchemaEntryPtrArryType),INTENT(IN) :: entry

      TYPE(SchemaEntryPtrArryType),ALLOCATABLE :: preventries(:)
      INTEGER(SIK) :: ientry,nEntries

      ! Append this card to the list of cards
      nEntries=SIZE(this%entry)
      ALLOCATE(preventries(nEntries))
      preventries=this%entry
      DEALLOCATE(this%entry)
      ALLOCATE(this%entry(nEntries+1))
      DO ientry=1,nEntries
        this%entry(ientry)=preventries(ientry)
      ENDDO
      this%entry(nEntries+1)=entry
    ENDSUBROUTINE addEntry_SchCrd
!
!-------------------------------------------------------------------------------
!> @brief Parsing routine for the given input file and card
!> @param this         the card to perform parsing
!> @param inputFile    the input file to be parsed
!> @param paramList    the target parameter list in which to put the parsed data
!> @param ioccurCrd    an integer representing the card occurrence being
!>                     considered
!> @param pListPathBlk the block parameter list path
!>
    SUBROUTINE parse_SchCrd(this,inputFile,paramList,ioccurCrd,pListPathBlk)
      CHARACTER(LEN=*),PARAMETER :: myName='parse_SchCrd'
      CLASS(SchemaCardType),INTENT(INOUT) :: this
      TYPE(InputFileType),INTENT(INOUT) :: inputFile
      TYPE(ParamType),INTENT(INOUT) :: paramList
      INTEGER(SIK),INTENT(IN) :: ioccurCrd
      TYPE(StringType),INTENT(IN) :: pListPathBlk

      INTEGER(SIK) :: nerr
      INTEGER(SIK) :: sttLine,stpLine,sttField,stpField
      TYPE(StringType) :: pListPath,line,fieldStr
      INTEGER(SIK) :: ientry,nEntries,iline,ifield
      TYPE(StringType),ALLOCATABLE :: entryStr(:)

      nerr=eSchemaParser%getCounter(EXCEPTION_ERROR)

      sttLine=this%startLine(ioccurCrd); stpLine=this%stopLine(ioccurCrd);
      sttField=this%startField(ioccurCrd); stpField=this%stopField(ioccurCrd);
      pListPath=pListPathBlk
      CALL this%addPLPath(pListPath,ioccurCrd)

      !Read the card entries into strings for each entry using the "/" as a delimiter
      nEntries=SIZE(this%entry)
      ALLOCATE(entryStr(nEntries))
      entryStr=''
      iline=0
      ientry=1
      DO WHILE(.NOT.atEndOfFile(inputFile))
        CALL inputfile%fgetl(line)
        iline=iline+1
        IF(iline>stpLine) EXIT
        IF(iline>=sttLine) THEN
          IF(atContentLine(inputFile)) THEN
            DO ifield=1,nFields(line)
              IF(iLine==stpLine .AND. ifield>stpField) EXIT
              IF(iline>sttLine .OR. ifield>sttField) THEN
                CALL getField(ifield,line,fieldStr)
                IF(fieldStr=="/") THEN 
                  ientry=ientry+1
                ELSE
                  entryStr(ientry)=entryStr(ientry)//fieldStr//' '
                ENDIF
              ENDIF
            ENDDO
          ENDIF
        ENDIF
      ENDDO
      CALL inputfile%frewind()      

      !Parse each Entry
      DO ientry=1,nEntries
        CALL this%entry(ientry)%entryPtr%parse(entryStr(ientry),paramList,pListPath)
      ENDDO

      IF(eSchemaParser%getCounter(EXCEPTION_ERROR) > nerr) THEN
        CALL eSchemaParser%raiseError(modName//'::'//myName//' - Error parsing card '//TRIM(this%name)//'!')
      ENDIF
    ENDSUBROUTINE parse_SchCrd
!
!-------------------------------------------------------------------------------
!> @brief Adds an SIK entry to the card
!> @param this        the card to add the entry to
!> @param pListPath   the parameter list path under which the entry data will be
!>                    put in the outgoing parameter list
!>
    SUBROUTINE addEntrySIK_SchCrd(this,pListPath)
      CLASS(SchemaCardType),INTENT(INOUT) :: this
      TYPE(StringType),INTENT(IN) :: pListPath

      TYPE(SchemaEntryPtrArryType) :: entry

      ALLOCATE(SchemaEntrySIKType :: entry%entryPtr)
      entry%entryPtr%pListPath=pListPath

      ! Append this card to the list of cards
      CALL this%addEntry(entry)
    ENDSUBROUTINE addEntrySIK_SchCrd
!
!-------------------------------------------------------------------------------
!> @brief Adds an SRK entry to the card
!> @param this        the card to add the entry to
!> @param pListPath   the parameter list path under which the entry data will be
!>                    put in the outgoing parameter list
!>
    SUBROUTINE addEntrySRK_SchCrd(this,pListPath)
      CLASS(SchemaCardType),INTENT(INOUT) :: this
      TYPE(StringType),INTENT(IN) :: pListPath

      TYPE(SchemaEntryPtrArryType) :: entry

      ALLOCATE(SchemaEntrySRKType :: entry%entryPtr)
      entry%entryPtr%pListPath=pListPath

      ! Append this card to the list of cards
      CALL this%addEntry(entry)
    ENDSUBROUTINE addEntrySRK_SchCrd
!
!-------------------------------------------------------------------------------
!> @brief Adds an SBK entry to the card
!> @param this        the card to add the entry to
!> @param pListPath   the parameter list path under which the entry data will be
!>                    put in the outgoing parameter list
!>
    SUBROUTINE addEntrySBK_SchCrd(this,pListPath)
      CLASS(SchemaCardType),INTENT(INOUT) :: this
      TYPE(StringType),INTENT(IN) :: pListPath

      TYPE(SchemaEntryPtrArryType) :: entry

      ALLOCATE(SchemaEntrySBKType :: entry%entryPtr)
      entry%entryPtr%pListPath=pListPath

      ! Append this card to the list of cards
      CALL this%addEntry(entry)
    ENDSUBROUTINE addEntrySBK_SchCrd
!
!-------------------------------------------------------------------------------
!> @brief Adds an string entry to the card
!> @param this        the card to add the entry to
!> @param pListPath   the parameter list path under which the entry data will be
!>                    put in the outgoing parameter list
!>
    SUBROUTINE addEntrySTR_SchCrd(this,pListPath)
      CLASS(SchemaCardType),INTENT(INOUT) :: this
      TYPE(StringType),INTENT(IN) :: pListPath

      TYPE(SchemaEntryPtrArryType) :: entry

      ALLOCATE(SchemaEntrySTRType :: entry%entryPtr)
      entry%entryPtr%pListPath=pListPath

      ! Append this card to the list of cards
      CALL this%addEntry(entry)
    ENDSUBROUTINE addEntrySTR_SchCrd
!
!-------------------------------------------------------------------------------
!> @brief Adds an SIKa1 entry to the card
!> @param this        the card to add the entry to
!> @param pListPath   the parameter list path under which the entry data will be
!>                    put in the outgoing parameter list
!>
    SUBROUTINE addEntrySIKa1_SchCrd(this,pListPath)
      CLASS(SchemaCardType),INTENT(INOUT) :: this
      TYPE(StringType),INTENT(IN) :: pListPath

      TYPE(SchemaEntryPtrArryType) :: entry

      ALLOCATE(SchemaEntrySIKa1Type :: entry%entryPtr)
      entry%entryPtr%pListPath=pListPath

      ! Append this card to the list of cards
      CALL this%addEntry(entry)
    ENDSUBROUTINE addEntrySIKa1_SchCrd
!
!-------------------------------------------------------------------------------
!> @brief Adds an SRKa1 entry to the card
!> @param this        the card to add the entry to
!> @param pListPath   the parameter list path under which the entry data will be
!>                    put in the outgoing parameter list
!>
    SUBROUTINE addEntrySRKa1_SchCrd(this,pListPath)
      CLASS(SchemaCardType),INTENT(INOUT) :: this
      TYPE(StringType),INTENT(IN) :: pListPath

      TYPE(SchemaEntryPtrArryType) :: entry

      ALLOCATE(SchemaEntrySRKa1Type :: entry%entryPtr)
      entry%entryPtr%pListPath=pListPath

      ! Append this card to the list of cards
      CALL this%addEntry(entry)
    ENDSUBROUTINE addEntrySRKa1_SchCrd
!
!-------------------------------------------------------------------------------
!> @brief Adds an SBKa1 entry to the card
!> @param this        the card to add the entry to
!> @param pListPath   the parameter list path under which the entry data will be
!>                    put in the outgoing parameter list
!>
    SUBROUTINE addEntrySBKa1_SchCrd(this,pListPath)
      CLASS(SchemaCardType),INTENT(INOUT) :: this
      TYPE(StringType),INTENT(IN) :: pListPath

      TYPE(SchemaEntryPtrArryType) :: entry

      ALLOCATE(SchemaEntrySBKa1Type :: entry%entryPtr)
      entry%entryPtr%pListPath=pListPath

      ! Append this card to the list of cards
      CALL this%addEntry(entry)
    ENDSUBROUTINE addEntrySBKa1_SchCrd
!
!-------------------------------------------------------------------------------
!> @brief Adds an string entry to the card
!> @param this        the card to add the entry to
!> @param pListPath   the parameter list path under which the entry data will be
!>                    put in the outgoing parameter list
!>
    SUBROUTINE addEntrySTRa1_SchCrd(this,pListPath)
      CLASS(SchemaCardType),INTENT(INOUT) :: this
      TYPE(StringType),INTENT(IN) :: pListPath

      TYPE(SchemaEntryPtrArryType) :: entry

      ALLOCATE(SchemaEntrySTRa1Type :: entry%entryPtr)
      entry%entryPtr%pListPath=pListPath

      ! Append this card to the list of cards
      CALL this%addEntry(entry)
    ENDSUBROUTINE addEntrySTRa1_SchCrd
!
!-------------------------------------------------------------------------------
!> @brief Routine clears the data in Schema Card type variable
!> @param this the type variable to clear
!>
    SUBROUTINE clear_SchCrd(this)
      CLASS(SchemaCardType),INTENT(INOUT) :: this

      INTEGER(SIK) ientry,nEntries

      nEntries=SIZE(this%entry)
      DO ientry=1,nEntries
        DEALLOCATE(this%entry(ientry)%entryPtr)
        this%entry(ientry)%entryPtr => NULL()
      ENDDO
      DEALLOCATE(this%entry)
    ENDSUBROUTINE clear_SchCrd
!
!-------------------------------------------------------------------------------
!> @brief Appends the give pListPath with the element path
!> @param this      the entry whose pListPath will be appended to the input
!>                  pListPath
!> @param pListPath the pListPath to append the entry pListPath to
!>
    SUBROUTINE addPLPath_SchEnt(this,pListPath)
      CLASS(SchemaEntryType),INTENT(IN) :: this
      TYPE(StringType),INTENT(INOUT) :: pListPath
      TYPE(StringType) :: tmpStr

      IF(this%pListPath=='') THEN
        CALL getSubstring(pListPath,tmpStr,1,LEN(pListPath)-2) !Trims off the '->' from the end
        pListPath=tmpStr
      ELSE
        pListPath=pListPath//this%pListPath
      ENDIF
    ENDSUBROUTINE addPLPath_SchEnt
!
!-------------------------------------------------------------------------------
!> @brief Parsing routine for the given SIK entry string
!> @param this         the entry to perform parsing
!> @param entryStr     the entry string to be parsed
!> @param paramList    the target parameter list in which to put the parsed data
!> @param pListPathCrd the card parameter list path
!>
    SUBROUTINE parseSIK_SchEnt(this,entryStr,paramList,pListPathCrd)
      CLASS(SchemaEntrySIKType),INTENT(IN) :: this
      CLASS(StringType),INTENT(IN) :: entryStr
      CLASS(ParamType),INTENT(INOUT) :: paramList
      TYPE(StringType),INTENT(IN) :: pListPathCrd

      TYPE(StringType) :: pListPath
      INTEGER(SIK) :: ierr
      INTEGER(SIK) :: entry

      !Add to path
      pListPath=pListPathCrd
      CALL this%addPLPath(pListPath)

      !Parse string into SIK
      IF(.NOT.isScalarEntry(entryStr)) RETURN
      IF(.NOT.isSIKEntry(entryStr)) RETURN
      CALL getField(1,entryStr,entry,ierr)

      !Add to parameter list
      CALL paramList%add(TRIM(pListPath),entry)

    ENDSUBROUTINE parseSIK_SchEnt
!
!-------------------------------------------------------------------------------
!> @brief Parsing routine for the given SRK entry string
!> @param this         the entry to perform parsing
!> @param entryStr     the entry string to be parsed
!> @param paramList    the target parameter list in which to put the parsed data
!> @param pListPathCrd the card parameter list path
!>
    SUBROUTINE parseSRK_SchEnt(this,entryStr,paramList,pListPathCrd)
      CLASS(SchemaEntrySRKType),INTENT(IN) :: this
      CLASS(StringType),INTENT(IN) :: entryStr
      CLASS(ParamType),INTENT(INOUT) :: paramList
      TYPE(StringType),INTENT(IN) :: pListPathCrd

      TYPE(StringType) :: pListPath
      INTEGER(SIK) :: ierr
      REAL(SRK) :: entry

      !Add to path
      pListPath=pListPathCrd
      CALL this%addPLPath(pListPath)

      !Parse string into SRK
      IF(.NOT.isScalarEntry(entryStr)) RETURN
      IF(.NOT.isSRKEntry(entryStr)) RETURN
      CALL getField(1,entryStr,entry,ierr)

      !Add to parameter list
      CALL paramList%add(TRIM(pListPath),entry)

    ENDSUBROUTINE parseSRK_SchEnt
!
!-------------------------------------------------------------------------------
!> @brief Parsing routine for the given SBK entry string
!> @param this         the entry to perform parsing
!> @param entryStr     the entry string to be parsed
!> @param paramList    the target parameter list in which to put the parsed data
!> @param pListPathCrd the card parameter list path
!>
    SUBROUTINE parseSBK_SchEnt(this,entryStr,paramList,pListPathCrd)
      CLASS(SchemaEntrySBKType),INTENT(IN) :: this
      CLASS(StringType),INTENT(IN) :: entryStr
      CLASS(ParamType),INTENT(INOUT) :: paramList
      TYPE(StringType),INTENT(IN) :: pListPathCrd

      TYPE(StringType) :: pListPath
      INTEGER(SIK) :: ierr
      TYPE(StringType) :: entry
      LOGICAL(SBK) :: entrySBK

      !Add to path
      pListPath=pListPathCrd
      CALL this%addPLPath(pListPath)

      !Parse string into SBK
      IF(.NOT.isScalarEntry(entryStr)) RETURN
      IF(.NOT.isSBKEntry(entryStr)) RETURN
      CALL getField(1,entryStr,entry,ierr)
      CALL toUPPER(entry)
      IF(entry=='TRUE' .OR. entry=='T') THEN
        entrySBK=.TRUE.
      ELSE
        entrySBK=.FALSE.
      ENDIF

      !Add to parameter list
      CALL paramList%add(TRIM(pListPath),entrySBK)

    ENDSUBROUTINE parseSBK_SchEnt
!
!-------------------------------------------------------------------------------
!> @brief Parsing routine for the given entry string
!> @param this         the entry to perform parsing
!> @param entryStr     the entry string to be parsed
!> @param paramList    the target parameter list in which to put the parsed data
!> @param pListPathCrd the card parameter list path
!>
    SUBROUTINE parseSTR_SchEnt(this,entryStr,paramList,pListPathCrd)
      CLASS(SchemaEntrySTRType),INTENT(IN) :: this
      CLASS(StringType),INTENT(IN) :: entryStr
      CLASS(ParamType),INTENT(INOUT) :: paramList
      TYPE(StringType),INTENT(IN) :: pListPathCrd

      TYPE(StringType) :: pListPath
      INTEGER(SIK) :: ierr
      TYPE(StringType) :: entry

      !Add to path
      pListPath=pListPathCrd
      CALL this%addPLPath(pListPath)

      !Parse string into STR
      IF(.NOT.isScalarEntry(entryStr)) RETURN
      CALL getField(1,entryStr,entry,ierr)

      !Add to parameter list
      CALL paramList%add(TRIM(pListPath),entry)

    ENDSUBROUTINE parseSTR_SchEnt
!
!-------------------------------------------------------------------------------
!> @brief Parsing routine for the given SIKa1 entry string
!> @param this         the entry to perform parsing
!> @param entryStr     the entry string to be parsed
!> @param paramList    the target parameter list in which to put the parsed data
!> @param pListPathCrd the card parameter list path
!>
    SUBROUTINE parseSIKa1_SchEnt(this,entryStr,paramList,pListPathCrd)
      CLASS(SchemaEntrySIKa1Type),INTENT(IN) :: this
      CLASS(StringType),INTENT(IN) :: entryStr
      CLASS(ParamType),INTENT(INOUT) :: paramList
      TYPE(StringType),INTENT(IN) :: pListPathCrd

      TYPE(StringType) :: pListPath,tmpstr
      INTEGER(SIK) :: ierr,ientry
      INTEGER(SIK),ALLOCATABLE :: entry(:)

      !Add to path
      pListPath=pListPathCrd
      CALL this%addPLPath(pListPath)

      !Parse string into SIKa1
      ALLOCATE(entry(nFields(entryStr)))
      DO ientry=1,nFields(entryStr)
        CALL getField(ientry,entryStr,tmpstr,ierr)
        IF(.NOT.isSIKEntry(tmpstr)) RETURN
        CALL getField(1,tmpstr,entry(ientry),ierr)
      ENDDO

      !Add to parameter list
      CALL paramList%add(TRIM(pListPath),entry)

    ENDSUBROUTINE parseSIKa1_SchEnt
!
!-------------------------------------------------------------------------------
!> @brief Parsing routine for the given SRKa1 entry string
!> @param this         the entry to perform parsing
!> @param entryStr     the entry string to be parsed
!> @param paramList    the target parameter list in which to put the parsed data
!> @param pListPathCrd the card parameter list path
!>
    SUBROUTINE parseSRKa1_SchEnt(this,entryStr,paramList,pListPathCrd)
      CLASS(SchemaEntrySRKa1Type),INTENT(IN) :: this
      CLASS(StringType),INTENT(IN) :: entryStr
      CLASS(ParamType),INTENT(INOUT) :: paramList
      TYPE(StringType),INTENT(IN) :: pListPathCrd

      TYPE(StringType) :: pListPath,tmpstr
      INTEGER(SIK) :: ierr,ientry
      REAL(SRK),ALLOCATABLE :: entry(:)

      !Add to path
      pListPath=pListPathCrd
      CALL this%addPLPath(pListPath)

      !Parse string into SRK
      ALLOCATE(entry(nFields(entryStr)))
      DO ientry=1,nFields(entryStr)
        CALL getField(ientry,entryStr,tmpstr,ierr)
        IF(.NOT.isSRKEntry(tmpstr)) RETURN
        CALL getField(1,tmpstr,entry(ientry),ierr)
      ENDDO

      !Add to parameter list
      CALL paramList%add(TRIM(pListPath),entry)

    ENDSUBROUTINE parseSRKa1_SchEnt
!
!-------------------------------------------------------------------------------
!> @brief Parsing routine for the given SBK entry string
!> @param this         the entry to perform parsing
!> @param entryStr     the entry string to be parsed
!> @param paramList    the target parameter list in which to put the parsed data
!> @param pListPathCrd the card parameter list path
!>
    SUBROUTINE parseSBKa1_SchEnt(this,entryStr,paramList,pListPathCrd)
      CLASS(SchemaEntrySBKa1Type),INTENT(IN) :: this
      CLASS(StringType),INTENT(IN) :: entryStr
      CLASS(ParamType),INTENT(INOUT) :: paramList
      TYPE(StringType),INTENT(IN) :: pListPathCrd

      TYPE(StringType) :: pListPath
      INTEGER(SIK) :: ierr,ientry
      TYPE(StringType) :: entry
      LOGICAL(SBK),ALLOCATABLE :: entrySBK(:)

      !Add to path
      pListPath=pListPathCrd
      CALL this%addPLPath(pListPath)

      !Parse string into SBK
      ALLOCATE(entrySBK(nFields(entryStr)))
      DO ientry=1,nFields(entryStr)
        CALL getField(ientry,entryStr,entry,ierr)
        IF(.NOT.isSBKEntry(entry)) RETURN
        CALL toUPPER(entry)
        IF(entry=='TRUE' .OR. entry=='T') THEN
          entrySBK(ientry)=.TRUE.
        ELSE
          entrySBK(ientry)=.FALSE.
        ENDIF
      ENDDO

      !Add to parameter list
      CALL paramList%add(TRIM(pListPath),entrySBK)

    ENDSUBROUTINE parseSBKa1_SchEnt
!
!-------------------------------------------------------------------------------
!> @brief Parsing routine for the given entry STRa1
!> @param this         the entry to perform parsing
!> @param entryStr     the entry string to be parsed
!> @param paramList    the target parameter list in which to put the parsed data
!> @param pListPathCrd the card parameter list path
!>
    SUBROUTINE parseSTRa1_SchEnt(this,entryStr,paramList,pListPathCrd)
      CLASS(SchemaEntrySTRa1Type),INTENT(IN) :: this
      CLASS(StringType),INTENT(IN) :: entryStr
      CLASS(ParamType),INTENT(INOUT) :: paramList
      TYPE(StringType),INTENT(IN) :: pListPathCrd

      TYPE(StringType) :: pListPath
      INTEGER(SIK) :: ierr,ientry
      TYPE(StringType),ALLOCATABLE :: entry(:)

      !Add to path
      pListPath=pListPathCrd
      CALL this%addPLPath(pListPath)

      !Parse string into STRa1
      ALLOCATE(entry(nFields(entryStr)))
      DO ientry=1,nFields(entryStr)
        CALL getField(ientry,entryStr,entry(ientry),ierr)
      ENDDO

      !Add to parameter list
      CALL paramList%add(TRIM(pListPath),entry)

    ENDSUBROUTINE parseSTRa1_SchEnt
!
!-------------------------------------------------------------------------------
!> @brief Finds the index which corresponds to the provided element name
!> @param elements  the element array to search for the given name
!> @param name      the element name we are looking to match in elements
!> @param index     the index number of the matching element in the array
!>
    FUNCTION findElementByName(elements,name) RESULT(index)
      CLASS(SchemaElementType),INTENT(IN) :: elements(:)
      TYPE(StringType),INTENT(IN) :: name
      INTEGER(SIK) :: index

      INTEGER(SIK) :: ielement

      !Ensure the provided blockName matches a block name on this schema
      index=UNDEFINED_ELEMENT
      DO ielement=1,SIZE(elements)
        IF(elements(ielement)%hasName(name)) THEN
          index=ielement
          EXIT
        ENDIF
      ENDDO
    ENDFUNCTION findElementByName
!
!-------------------------------------------------------------------------------
!> @brief Determines if the input text file line is currently at End of the File
!> @param file   the file currently being read
!> @param isEOF  logical determining whether or not the file is at End of File
!>
    FUNCTION atEndOfFile(file) RESULT(isEOF)
      TYPE(InputFileType),INTENT(IN) :: file
      LOGICAL(SBK) :: isEOF

      REQUIRE(file%isOpen())
      isEOF=file%isEOF() .OR. file%getProbe()==DOT
    ENDFUNCTION atEndOfFile
!
!-------------------------------------------------------------------------------
!> @brief Determines if the input text file line contains readable content
!> @param file        the file currently being read
!> @param hasContent  logical determining whether or not the file has content
!>
    FUNCTION atContentLine(file) RESULT(hasContent)
      TYPE(InputFileType),INTENT(IN) :: file
      LOGICAL(SBK) :: hasContent
      TYPE(StringType) :: line

      REQUIRE(file%isOpen())
      hasContent=file%getProbe()/=BANG .AND. file%getProbe() /= DOT
    ENDFUNCTION atContentLine
!
!-------------------------------------------------------------------------------
!> @brief Checks to see if entry string is empty
!> @param string   the string to be checked
!> @param isValid  logical corresponding to if the entry string is empty
!>
    FUNCTION isEmptyEntry(string) RESULT(isValid)
      CHARACTER(LEN=*),PARAMETER :: myName='isEmptyEntry'
      TYPE(StringType),INTENT(IN) :: string
      LOGICAL(SBK) :: isValid

      isValid=.FALSE.
      IF(.NOT.nFields(string)>0) THEN
        isValid=.TRUE.
        CALL eSchemaParser%raiseError(modName//'::'//myName// &
          ' - Entry string contains no entries!')
      ENDIF
    ENDFUNCTION isEmptyEntry
!
!-------------------------------------------------------------------------------
!> @brief Checks to ensure a string has a single field (i.e. is scalar value)
!> @param string   the string to be checked   
!> @param isValid  logical corresponding to if the string is a scalar
!>
    FUNCTION isScalarEntry(string) RESULT(isValid)
      CHARACTER(LEN=*),PARAMETER :: myName='isSingleEntry'
      TYPE(StringType),INTENT(IN) :: string
      LOGICAL(SBK) :: isValid

      isValid=.NOT.isEmptyEntry(string)
      IF(nFields(string)>2) THEN
        isValid=.FALSE.
        CALL eSchemaParser%raiseError(modName//'::'//myName// &
          ' - Expected Scalar entry but provided multiple entries at "'//TRIM(string)//'"!')
      ENDIF
    ENDFUNCTION isScalarEntry
!
!-------------------------------------------------------------------------------
!> @brief Checks to ensure an entry is a valid SIK entry
!> @param string   the string to be checked   
!> @param isValid  logical corresponding to if the string is valid
!>
    FUNCTION isSIKEntry(string) RESULT(isValid)
      CHARACTER(LEN=*),PARAMETER :: myName='isSIKEntry'
      TYPE(StringType),INTENT(IN) :: string
      LOGICAL(SBK) :: isValid

      INTEGER(SIK) :: entry,ioerr

      REQUIRE(isScalarEntry(string))

      isValid=.TRUE.
      CALL getField(1,string,entry,ioerr)
      IF(ioerr/=0) THEN
        isValid=.FALSE.
        CALL eSchemaParser%raiseError(modName//'::'//myName// &
          ' - Expected Integer_SIK entry but provided other data type at "'//TRIM(string)//'"!')
      ENDIF
    ENDFUNCTION isSIKEntry
!
!-------------------------------------------------------------------------------
!> @brief Checks to ensure an entry is a valid SRK entry
!> @param string   the string to be checked
!> @param isValid  logical corresponding to if the string is valid
!>
    FUNCTION isSRKEntry(string) RESULT(isValid)
      CHARACTER(LEN=*),PARAMETER :: myName='isSRKEntry'
      TYPE(StringType),INTENT(IN) :: string
      LOGICAL(SBK) :: isValid

      REAL(SRK) :: entry
      INTEGER(SIK) :: ioerr

      REQUIRE(isScalarEntry(string))

      isValid=.TRUE.
      CALL getField(1,string,entry,ioerr)
      IF(ioerr/=0) THEN
        isValid=.FALSE.
        CALL eSchemaParser%raiseError(modName//'::'//myName// &
          ' - Expected Real_SRK entry but provided other data type at "'//TRIM(string)//'"!')
      ENDIF
    ENDFUNCTION isSRKEntry
!
!-------------------------------------------------------------------------------
!> @brief Checks to ensure an entry is a valid SBK entry
!> @param string   the string to be checked
!> @param isValid  logical corresponding to if the string is valid
!>
    FUNCTION isSBKEntry(string) RESULT(isValid)
      CHARACTER(LEN=*),PARAMETER :: myName='isSBKEntry'
      TYPE(StringType),INTENT(IN) :: string
      LOGICAL(SBK) :: isValid

      TYPE(StringType) :: entry
      INTEGER(SIK) :: ioerr

      REQUIRE(isScalarEntry(string))

      isValid=.TRUE.
      CALL getField(1,string,entry)
      CALL toUPPER(entry)
      IF(.NOT.(entry=='TRUE' .OR. entry=='T' .OR. entry=='FALSE' .OR. entry=='F')) THEN
        isValid=.FALSE.
        CALL eSchemaParser%raiseError(modName//'::'//myName// &
          ' - Expected Logical_SBK entry but provided other data type at "'//TRIM(string)//'"!')
      ENDIF
    ENDFUNCTION isSBKEntry
!
ENDMODULE SchemaParser

