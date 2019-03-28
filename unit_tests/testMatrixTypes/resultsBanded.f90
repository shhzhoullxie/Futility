!++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++!
!                          Futility Development Group                          !
!                             All rights reserved.                             !
!                                                                              !
! Futility is a jointly-maintained, open-source project between the University !
! of Michigan and Oak Ridge National Laboratory.  The copyright and license    !
! can be found in LICENSE.txt in the head directory of this repository.        !
!++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++!
PROGRAM testMatrixTypes
#include "Futility_DBC.h"
#include "UnitTest.h"
  USE ISO_FORTRAN_ENV
  USE ISO_C_BINDING
  USE UnitTest
  USE IntrType
  USE ExceptionHandler
  USE Futility_DBC
  USE trilinos_interfaces
  USE ParameterLists
  USE ParallelEnv
  USE VectorTypes
  USE MatrixTypes

  IMPLICIT NONE

#ifdef FUTILITY_HAVE_PETSC
#include <petscversion.h>
#if ((PETSC_VERSION_MAJOR>=3) && (PETSC_VERSION_MINOR>=6))
#include <petsc/finclude/petsc.h>
#else
#include <finclude/petsc.h>
#endif
#undef IS
  PetscErrorCode  :: ierr
#else
#ifdef HAVE_MPI
#include <mpif.h>
  INTEGER :: ierr
#endif
#endif

  TYPE(ExceptionHandlerType),TARGET :: e
  TYPE(ParamType) :: pList,optListMat,vecPList

  !Configure exception handler for test
  CALL e%setStopOnError(.FALSE.)
  CALL e%setQuietMode(.TRUE.)
  CALL eParams%addSurrogate(e)
  CALL eMatrixType%addSurrogate(e)

#ifdef FUTILITY_HAVE_PETSC
  CALL PetscInitialize(PETSC_NULL_CHARACTER,ierr)
#else
#ifdef HAVE_MPI
  CALL MPI_Init(ierr)
#endif
#endif

  CREATE_TEST('Verify results')
  REGISTER_SUBTEST('Products Match',verifyFD)
  REGISTER_SUBTEST('Products Match',verifyCMFD)

  CREATE_TEST('Matvec FD Timing Results')
  REGISTER_SUBTEST('Petsc',timePetsc)
  REGISTER_SUBTEST('Banded',timeBanded)

  CREATE_TEST('Matvec CMFD Timing Results')
  REGISTER_SUBTEST('Petsc',timePetscCMFD)
  REGISTER_SUBTEST('Banded',timeBandedCMFD)
  FINALIZE_TEST()

  CALL optListMat%clear()
  CALL vecPList%clear()
  CALL pList%clear()
  CALL MatrixTypes_Clear_ValidParams()
  CALL VectorType_Clear_ValidParams()

#ifdef FUTILITY_HAVE_PETSC
  CALL PetscFinalize(ierr)
#endif

!
!===============================================================================
  CONTAINS
!
!-------------------------------------------------------------------------------

    SUBROUTINE verifyFD()
      CLASS(BandedMatrixType),ALLOCATABLE :: fdBanded
      CLASS(PETScMatrixType),ALLOCATABLE :: fdPetsc
      REAL(SRK),ALLOCATABLE :: x(:),y(:),dummyvec(:)
      CLASS(PETScVectorType),ALLOCATABLE :: xPetsc, yPetsc
      TYPE(ParamType) :: bandedPlist,petscPList,vecPList
      INTEGER(SIK) :: i,j,xcoord,ycoord,n,nnz,gridsize
      LOGICAL(SBK) :: bool

      ALLOCATE(BandedMatrixType :: fdBanded)
      ALLOCATE(PETScMatrixType :: fdPetsc)

      n = 16384
      gridSize = 128
      nnz = 1
      IF (n > 1) THEN
        nnz = nnz + 11
      END IF
      IF (n > 2) THEN
        nnz = nnz + 5*(gridSize-2)*(gridSize-2) + 16*(gridSize-2)
      END IF

      CALL bandedPList%clear()
      CALL bandedPlist%add('MatrixType->n',n)
      CALL bandedPlist%add('MatrixType->m',n)
      CALL bandedPlist%add('MatrixType->nnz',nnz)

      CALL petscPList%clear()
      CALL petscPlist%add('MatrixType->n',n)
      CALL petscPlist%add('MatrixType->m',n)
      CALL petscPlist%add('MatrixType->nnz',nnz)
      CALL petscPlist%add('MatrixType->isSym',.FALSE.)
      CALL petscPlist%add('MatrixType->matType',SPARSE)
      CALL petscPlist%add('MatrixType->MPI_Comm_ID',PE_COMM_SELF)

      CALL vecPList%clear()
      CALL vecPList%add('VectorType->n',n)
      CALL vecPList%add('VectorType->MPI_Comm_ID',PE_COMM_SELF)


      CALL fdBanded%init(bandedPList)
      CALL fdPetsc%init(petscPList)

      ALLOCATE(x(n))
      ALLOCATE(y(n))
      ALLOCATE(dummyvec(n))
      ALLOCATE(petscVectorType :: xPetsc)
      ALLOCATE(petscVectorType :: yPetsc)

      CALL xPetsc%init(vecPList)
      CALL yPetsc%init(vecPList)

      x = 1.0_SRK
      CALL xPetsc%set(1.0_SRK)
      CALL yPetsc%set(0.0_SRK)

      DO i=1,n
        yCoord = (i-1)/gridSize
        xCoord = MOD(i-1,gridSize)
        IF (yCoord > 0) THEN
          CALL fdBanded%set(i,i-gridSize,-1.0_SRK)
          CALL fdPetsc%set(i,i-gridSize,-1.0_SRK)
        END IF
        IF (xCoord > 0) THEN
          CALL fdBanded%set(i, i-1,-1.0_SRK)
          CALL fdPetsc%set(i, i-1,-1.0_SRK)
        END IF
        CALL fdBanded%set(i,i,4.0_SRK)
        CALL fdPetsc%set(i,i,4.0_SRK)
        IF (xCoord < gridSize-1) THEN
          CALL fdBanded%set(i, i+1,-1.0_SRK)
          CALL fdPetsc%set(i, i+1,-1.0_SRK)
        END IF
        IF (yCoord < gridSize-1) THEN
          CALL fdBanded%set(i,i+gridSize,-1.0_SRK)
          CALL fdPetsc%set(i,i+gridSize,-1.0_SRK)
        END IF
      END DO
      WRITE(*,*) "Completed set"
      CALL fdBanded%assemble()
      CALL fdPetsc%assemble()
      WRITE(*,*) "Completed assemble"

      CALL BLAS_matvec(THISMATRIX=fdBanded,X=x,Y=y)
      CALL BLAS_matvec(THISMATRIX=fdPetsc,X=xPetsc,Y=yPetsc)

      WRITE(*,*) "Completed mult"
      CALL yPetsc%getAll(dummyvec)
      WRITE(*,*) "Completed get"
      bool = ALL(y .APPROXEQ. dummyvec)
      ASSERT(bool,'Matvec results match')

      CALL vecPList%clear()
      CALL petscPList%clear()
      CALL bandedPlist%clear()

    END SUBROUTINE verifyFD

    SUBROUTINE verifyCMFD()
      CLASS(BandedMatrixType),ALLOCATABLE :: cmfdBanded
      CLASS(PETScMatrixType),ALLOCATABLE :: cmfdPetsc
      REAL(SRK),ALLOCATABLE :: x(:),y(:),dummyvec(:)
      REAL(SRK) :: tmpreal
      CLASS(PETScVectorType),ALLOCATABLE :: xPetsc, yPetsc
      TYPE(ParamType) :: bandedPlist,petscPList,vecPList
      INTEGER(SIK) :: i,j,xcoord,ycoord,n,nnz,gridsize,ios
      LOGICAL(SBK) :: bool
      CHARACTER(200)::tempcharacter,dirname


      ALLOCATE(BandedMatrixType :: cmfdBanded)
      ALLOCATE(PETScMatrixType :: cmfdPetsc)

      n = 1512
      nnz = 67200

      CALL bandedPList%clear()
      CALL bandedPlist%add('MatrixType->n',n)
      CALL bandedPlist%add('MatrixType->m',n)
      CALL bandedPlist%add('MatrixType->nnz',nnz)

      CALL petscPList%clear()
      CALL petscPlist%add('MatrixType->n',n)
      CALL petscPlist%add('MatrixType->m',n)
      CALL petscPlist%add('MatrixType->nnz',nnz)
      CALL petscPlist%add('MatrixType->isSym',.FALSE.)
      CALL petscPlist%add('MatrixType->matType',SPARSE)
      CALL petscPlist%add('MatrixType->MPI_Comm_ID',PE_COMM_SELF)

      CALL vecPList%clear()
      CALL vecPList%add('VectorType->n',n)
      CALL vecPList%add('VectorType->MPI_Comm_ID',PE_COMM_SELF)


      CALL cmfdBanded%init(bandedPList)
      CALL cmfdPetsc%init(petscPList)

      ALLOCATE(x(n))
      ALLOCATE(y(n))
      ALLOCATE(dummyvec(n))
      ALLOCATE(petscVectorType :: xPetsc)
      ALLOCATE(petscVectorType :: yPetsc)

      CALL xPetsc%init(vecPList)
      CALL yPetsc%init(vecPList)

      x = 1.0_SRK
      CALL xPetsc%setAll_scalar(1.0_SRK)

      !WRITE(dirname,'(2A)'),'/home/mkbz/Research/bandMatResults/Futility/unit_tests/testPreconditionerTypes/matrices/mg_matrix.txt'
      WRITE(dirname,'(2A)'),'/home/mkbz/git/Futility/unit_tests/testLinearSolver/matrices/mg_matrix.txt'

      OPEN(UNIT=11,FILE=dirname,STATUS='OLD',ACTION='READ',IOSTAT=ios,IOMSG=tempcharacter)
      IF(ios .NE. 0)THEN
          WRITE(*,*)tempcharacter
          WRITE(*,*)'Could not open res.dat'
          STOP
      END IF
      READ(11,*)
      DO
          READ(11,*,IOSTAT=ios)i,j,tmpreal
          IF(ios >0)THEN
              STOP 'File input error'
          ELSE IF(ios<0)THEN
              EXIT
          ELSE
            CALL cmfdBanded%set(i,j,tmpreal)
            CALL cmfdPetsc%set(i,j,tmpreal)
          END IF
      END DO
      CLOSE(11)


      WRITE(*,*) "Completed set"
      CALL cmfdBanded%assemble()
      CALL cmfdPetsc%assemble()
      WRITE(*,*) "Completed assemble"

      CALL BLAS_matvec(THISMATRIX=cmfdBanded,X=x,Y=y)
      CALL BLAS_matvec(THISMATRIX=cmfdPetsc,X=xPetsc,Y=yPetsc)

      WRITE(*,*) "Completed mult"
      CALL yPetsc%getAll(dummyvec)
      WRITE(*,*) "Completed get"
      bool = ALL(y .APPROXEQ. dummyvec)
      WRITE(*,*) "Found bool"
      ASSERT(bool,'Matvec results match')

      CALL vecPList%clear()
      CALL petscPList%clear()
      CALL bandedPlist%clear()

    END SUBROUTINE verifyCMFD

    SUBROUTINE timeBanded()

      CLASS(BandedMatrixType),ALLOCATABLE :: fdBanded
      REAL(SRK),ALLOCATABLE :: x(:),y(:)
      REAL(SRK) :: timetaken
      INTEGER(SIK) :: i,n,nnz,xCoord,yCoord,gridSize,time1,time2,clock_rate
      TYPE(ParamType) :: bandedPlist

      ! Create finite difference matrix
      ALLOCATE(BandedMatrixType :: fdBanded)
      n = 16384
      gridSize = 128
      nnz = 1
      IF (n > 1) THEN
        nnz = nnz + 11
      END IF
      IF (n > 2) THEN
        nnz = nnz + 5*(gridSize-2)*(gridSize-2) + 16*(gridSize-2)
      END IF
      CALL bandedPlist%add('MatrixType->n',n)
      CALL bandedPlist%add('MatrixType->m',n)
      CALL bandedPlist%add('MatrixType->nnz',nnz)
      CALL bandedPlist%validate(bandedPlist)
      CALL fdBanded%init(bandedPlist)

      DO i=1,n
        yCoord = (i-1)/gridSize
        xCoord = MOD(i-1,gridSize)
        IF (yCoord > 0) THEN
          CALL fdBanded%set(i,i-gridSize,-1.0_SRK)
        END IF
        IF (xCoord > 0) THEN
          CALL fdBanded%set(i, i-1,-1.0_SRK)
        END IF
        CALL fdBanded%set(i,i,4.0_SRK)
        IF (xCoord < gridSize-1) THEN
          CALL fdBanded%set(i, i+1,-1.0_SRK)
        END IF
        IF (yCoord < gridSize-1) THEN
          CALL fdBanded%set(i,i+gridSize,-1.0_SRK)
        END IF
      END DO

      WRITE(*,*) "Beginning Assemble"
      CALL SYSTEM_CLOCK(time1)
      CALL fdBanded%assemble()
      CALL SYSTEM_CLOCK(time2,clock_rate)
      timetaken = (time2*1.0_SRK - time1*1.0_SRK)/(clock_rate*1.0_SRK)
      WRITE(*,*) "Assembly Completed in",timeTaken,"seconds"

      ALLOCATE(x(n))
      ALLOCATE(y(n))

      x = 1.0_SRK

      ! Get clock
      CALL SYSTEM_CLOCK(time1)
        ! Loop multiply banded*x = y
      DO i=1,n
        CALL BLAS_matvec(THISMATRIX=fdBanded,X=x,Y=y)
      END DO
      ! Get clock
      CALL SYSTEM_CLOCK(time2,clock_rate)
      ! report total time
      timetaken = (time2*1.0_SRK - time1*1.0_SRK)/(clock_rate*1.0_SRK)
      WRITE(*,*) n,"Multiplications completed in",timetaken,"seconds"

      CALL optListMat%clear()
      CALL vecPList%clear()
      CALL pList%clear()

    END SUBROUTINE timeBanded


    SUBROUTINE timePetsc()
      CLASS(PETScMatrixType),ALLOCATABLE :: fdPetsc
      CLASS(VectorType),ALLOCATABLE :: x,y
      TYPE(ParamType) :: petscPlist
      INTEGER(SIK) :: xCoord,yCoord,i,gridsize,n,nnz,time1,time2,clock_rate
      REAL(SRK) :: timeTaken

      ! Create finite difference matrix
      n = 16384
      gridSize = 128
      nnz = 1
      IF (n > 1) THEN
        nnz = nnz + 11
      END IF
      IF (n > 2) THEN
        nnz = nnz + 5*(gridSize-2)*(gridSize-2) + 16*(gridSize-2)
      END IF

      ALLOCATE(PETScMatrixType :: fdPetsc)
      CALL petscPlist%add('MatrixType->n',n)
      CALL petscPlist%add('MatrixType->m',n)
      CALL petscPlist%add('MatrixType->nnz',nnz)
      CALL petscPlist%add('MatrixType->isSym',.FALSE.)
      CALL petscPlist%add('MatrixType->matType',SPARSE)
      CALL petscPlist%add('MatrixType->MPI_Comm_ID',PE_COMM_SELF)
      CALL petscPlist%validate(petscPlist)
      CALL fdPetsc%init(petscPlist)

      CALL vecPList%add('VectorType->n',n)
      CALL vecPList%add('VectorType->MPI_Comm_ID',PE_COMM_SELF)

      ALLOCATE(PETScVectorType :: x)
      ALLOCATE(PETScVectorType :: y)
      CALL x%init(vecPList)
      CALL y%init(vecPList)

      DO i=1,n
        yCoord = (i-1)/gridSize
        xCoord = MOD(i-1,gridSize)
        IF (yCoord > 0) THEN
          CALL fdPetsc%set(i,i-gridSize,-1.0_SRK)
        END IF
        IF (xCoord > 0) THEN
          CALL fdPetsc%set(i, i-1,-1.0_SRK)
        END IF
        CALL fdPetsc%set(i,i,4.0_SRK)
        IF (xCoord < gridSize-1) THEN
          CALL fdPetsc%set(i, i+1,-1.0_SRK)
        END IF
        IF (yCoord < gridSize-1) THEN
          CALL fdPetsc%set(i,i+gridSize,-1.0_SRK)
        END IF
      END DO
      CALL fdPetsc%assemble()

      CALL x%setAll_scalar(1.0_SRK)

      ! Get clock
      WRITE(*,*) "Beginning multiplication loop"
      CALL SYSTEM_CLOCK(time1)
        ! Loop multiply banded*x = y
      DO i=1,n
        CALL BLAS_matvec(THISMATRIX=fdPetsc,X=x,Y=y)
      END DO
      ! Get clock
      CALL SYSTEM_CLOCK(time2,clock_rate)
      ! report total time
      timetaken = (time2*1.0_SRK - time1*1.0_SRK)/(clock_rate*1.0_SRK)
      WRITE(*,*) n,"Multiplications completed in",timetaken,"seconds"

      CALL optListMat%clear()
      CALL vecPList%clear()
      CALL pList%clear()

    END SUBROUTINE timePetsc

    SUBROUTINE timeBandedCMFD()

      CLASS(BandedMatrixType),ALLOCATABLE :: cmfdBanded
      REAL(SRK),ALLOCATABLE :: x(:),y(:)
      REAL(SRK) :: timetaken,tmpreal
      INTEGER(SIK) :: i,j,n,nnz,xCoord,yCoord,gridSize,time1,time2,clock_rate,ios
      CHARACTER(200)::tempcharacter,dirname
      TYPE(ParamType) :: bandedPlist

      ! Create finite difference matrix
      ALLOCATE(BandedMatrixType :: cmfdBanded)

      !WRITE(dirname,'(2A)'),'/home/mkbz/Research/bandMatResults/Futility/unit_tests/testPreconditionerTypes/matrices/mg_matrix.txt'
      WRITE(dirname,'(2A)'),'/home/mkbz/git/Futility/unit_tests/testLinearSolver/matrices/mg_matrix.txt'

      nnz = 67200
      n = 1512
      CALL bandedPlist%add('MatrixType->n',n)
      CALL bandedPlist%add('MatrixType->m',n)
      CALL bandedPlist%add('MatrixType->nnz',nnz)
      CALL bandedPlist%validate(bandedPlist)
      CALL cmfdBanded%init(bandedPlist)

      OPEN(UNIT=11,FILE=dirname,STATUS='OLD',ACTION='READ',IOSTAT=ios,IOMSG=tempcharacter)
      IF(ios .NE. 0)THEN
          WRITE(*,*)tempcharacter
          WRITE(*,*)'Could not open res.dat'
          STOP
      END IF
      READ(11,*)
      DO
          READ(11,*,IOSTAT=ios)i,j,tmpreal
          IF(ios >0)THEN
              STOP 'File input error'
          ELSE IF(ios<0)THEN
              EXIT
          ELSE
              CALL cmfdBanded%set(i,j,tmpreal)
          END IF
      END DO
      CLOSE(11)
      WRITE(*,*) "Beginning Assemble"
      CALL SYSTEM_CLOCK(time1)
      CALL cmfdBanded%assemble()
      CALL SYSTEM_CLOCK(time2,clock_rate)
      timetaken = (time2*1.0_SRK - time1*1.0_SRK)/(clock_rate*1.0_SRK)
      WRITE(*,*) "Assembly completed in",timetaken,"seconds"

      ALLOCATE(x(n))
      ALLOCATE(y(n))

      x = 1.0_SRK

      ! Get clock
      CALL SYSTEM_CLOCK(time1)
        ! Loop multiply banded*x = y
      DO i=1,64*n
        CALL BLAS_matvec(THISMATRIX=cmfdBanded,X=x,Y=y)
      END DO
      ! Get clock
      CALL SYSTEM_CLOCK(time2,clock_rate)
      ! report total time
      timetaken = (time2*1.0_SRK - time1*1.0_SRK)/(clock_rate*1.0_SRK)
      WRITE(*,*) 64*n,"Multiplications completed in",timetaken,"seconds"

      CALL optListMat%clear()
      CALL vecPList%clear()
      CALL pList%clear()

    END SUBROUTINE timeBandedCMFD


    SUBROUTINE timePetscCMFD()
      CLASS(PetscMatrixType),ALLOCATABLE :: cmfdPetsc
      CLASS(VectorType),ALLOCATABLE :: x,y
      TYPE(ParamType) :: petscPlist
      INTEGER(SIK) :: xCoord,yCoord,i,gridsize,n,nnz,time1,time2,clock_rate,ios,j
      REAL(SRK) :: timeTaken,tmpreal
      CHARACTER(200)::tempcharacter,dirname


      !WRITE(dirname,'(2A)'),'/home/mkbz/Research/bandMatResults/Futility/unit_tests/testPreconditionerTypes/matrices/mg_matrix.txt'
      WRITE(dirname,'(2A)'),'/home/mkbz/git/Futility/unit_tests/testLinearSolver/matrices/mg_matrix.txt'
      ! Create finite difference matrix
      nnz = 67200
      n = 1512

      ALLOCATE(PETScMatrixType :: cmfdPetsc)
      CALL petscPlist%add('MatrixType->n',n)
      CALL petscPlist%add('MatrixType->m',n)
      CALL petscPlist%add('MatrixType->nnz',nnz)
      CALL petscPlist%add('MatrixType->isSym',.FALSE.)
      CALL petscPlist%add('MatrixType->matType',SPARSE)
      CALL petscPlist%add('MatrixType->MPI_Comm_ID',PE_COMM_SELF)
      CALL petscPlist%validate(petscPlist)
      CALL cmfdPetsc%init(petscPlist)

      CALL vecPList%add('VectorType->n',n)
      CALL vecPList%add('VectorType->MPI_Comm_ID',PE_COMM_SELF)

      ALLOCATE(PETScVectorType :: x)
      ALLOCATE(PETScVectorType :: y)
      CALL x%init(vecPList)
      CALL y%init(vecPList)

      OPEN(UNIT=11,FILE=dirname,STATUS='OLD',ACTION='READ',IOSTAT=ios,IOMSG=tempcharacter)
      IF(ios .NE. 0)THEN
          WRITE(*,*)tempcharacter
          WRITE(*,*)'Could not open res.dat'
          STOP
      END IF
      READ(11,*)
      DO
          READ(11,*,IOSTAT=ios)i,j,tmpreal
          IF(ios >0)THEN
              STOP 'File input error'
          ELSE IF(ios<0)THEN
              EXIT
          ELSE
              CALL cmfdPetsc%set(i,j,tmpreal)
          END IF
      END DO
      CLOSE(11)
      CALL cmfdPetsc%assemble()
      CALL x%setAll_scalar(1.0_SRK)

      ! Get clock
      WRITE(*,*) "Beginning multiplication loop"
      CALL SYSTEM_CLOCK(time1)
        ! Loop multiply banded*x = y
      DO i=1,64*n
        CALL BLAS_matvec(THISMATRIX=cmfdPetsc,X=x,Y=y)
      END DO
      ! Get clock
      CALL SYSTEM_CLOCK(time2,clock_rate)
      ! report total time
      timetaken = (time2*1.0_SRK - time1*1.0_SRK)/(clock_rate*1.0_SRK)
      WRITE(*,*) 64*n,"Multiplications completed in",timetaken,"seconds"

      CALL optListMat%clear()
      CALL vecPList%clear()
      CALL pList%clear()

    END SUBROUTINE timePetscCMFD

ENDPROGRAM testMatrixTypes