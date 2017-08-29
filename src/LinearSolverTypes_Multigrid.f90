!++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++!
!                          Futility Development Group                          !
!                             All rights reserved.                             !
!                                                                              !
! Futility is a jointly-maintained, open-source project between the University !
! of Michigan and Oak Ridge National Laboratory.  The copyright and license    !
! can be found in LICENSE.txt in the head directory of this repository.        !
!++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++!
!> @brief Module provides a linear system type and methods to solve systems
!> of equations via a multigrid method
!>
!> For valid reference lists
!> see @ref MatrixTypes::LinearSolverTypes_Declare_ValidParams
!> "LinearSolverTypes_Declare_ValidParams".
!>
!> Currently supported TPLs include:
!>  - PETSc (with interfaces to KSP)
!>
!> @par Module Dependencies
!>  - @ref IntrType "IntrType": @copybrief IntrType
!>  - @ref BLAS "BLAS": @copybrief BLAS
!>  - @ref Times "Times": @copybrief Times
!>  - @ref ExceptionHandler "ExceptionHandler": @copybrief ExceptionHandler
!>  - @ref Allocs "Allocs": @copybrief Allocs
!>  - @ref ParameterLists "ParameterLists": @copybrief ParameterLists
!>  - @ref ParallelEnv "ParallelEnv": @copybrief ParallelEnv
!>  - @ref VectorTypes "VectorTypes": @copybrief VectorTypes
!>  - @ref MatrixTypes "MatrixTypes": @copybrief MatrixTypes
!>  - @ref LinearSolverTypes "LinearSolverTypes": @copybrief LinearSolverTypes
!>
!> @par EXAMPLES
!> @code
!>
!> @endcode
!>
!> @author Ben C. Yee
!>   @date 08/22/2017
!>
!++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++!
MODULE LinearSolverTypes_Multigrid
  USE IntrType
  USE BLAS
  USE trilinos_interfaces
  USE Times
  USE ExceptionHandler
  USE Allocs
  USE ParameterLists
  USE ParallelEnv
  USE VectorTypes
  USE MatrixTypes
  USE PreconditionerTypes
  USE Strings
  USE IOUtil
  USE LinearSolverTypes
  IMPLICIT NONE

#ifdef FUTILITY_HAVE_PETSC
#include <petscversion.h>
#if ((PETSC_VERSION_MAJOR>=3) && (PETSC_VERSION_MINOR>=6))
#include <petsc/finclude/petsc.h>
#else
#include <finclude/petsc.h>
#endif
!petscisdef.h defines the keyword IS, and it needs to be reset
#undef IS
#endif
!
! List of public members
  PUBLIC :: LinearSolverType_Multigrid

  INTEGER(SIK),PARAMETER :: max_levels=8_SIK

  !> @brief The extended type for the Iterative Linear Solver
  TYPE,EXTENDS(LinearSolverType_Iterative) :: LinearSolverType_Multigrid
    !> Number of grids:
    INTEGER(SIK) :: nLevels=1_SIK
    !> Whether or not the restriciton, interpolation, and smoothing is ready:
    LOGICAL(SBK) :: isMultigridSetup=.FALSE.
    !> Size of each grid level_info(level,:) = (/num_eqns,nx,ny,nz/)
    INTEGER(SIK),ALLOCATABLE :: level_info(:,:)
#ifdef FUTILITY_HAVE_PETSC
    !> Size of each grid locally
    INTEGER(SIK),ALLOCATABLE :: level_info_local(:,:)
    !> Array of PETSc interpolation matrices
    TYPE(PETScMatrixType),ALLOCATABLE :: interpMats(:)
#endif

    CONTAINS
      !> @copybrief TODO
      !> @copydetails TODO
      PROCEDURE,PASS :: init => init_LinearSolverType_Multigrid
      !> @copybrief TODO
      !> @copydetails TODO
      PROCEDURE,PASS :: preAllocPETScInterpMat => &
                          preAllocPETScInterpMat_LinearSolverType_Multigrid
      !> @copybrief TODO
      !> @copydetails TODO
      PROCEDURE,PASS :: setupPETScMG => setupPETScMG_LinearSolverType_Multigrid
      !> @copybrief TODO
      !> @copydetails TODO
      PROCEDURE,PASS :: clear => clear_LinearSolverType_Multigrid
  ENDTYPE LinearSolverType_Multigrid

  !> Logical flag to check whether the required and optional parameter lists
  !> have been created yet for the Linear Solver Type.
  LOGICAL(SBK),SAVE :: LinearSolverType_Paramsflag=.FALSE.

  !> Name of module
  CHARACTER(LEN=*),PARAMETER :: modName='LINEARSOLVERTYPES_MULTIGRID'
!
!===============================================================================
  CONTAINS
!
!-------------------------------------------------------------------------------
!> @brief Initializes the multigrid Linear Solver Type with a parameter list
!>
!> @param solver The linear solver to act on
!> @param Params the parameter list
!> @param A The A operator in Ax=b
!>
    SUBROUTINE init_LinearSolverType_Multigrid(solver,Params,A)
      CHARACTER(LEN=*),PARAMETER :: myName='init_LinearSolverType_Multigrid'
      CLASS(LinearSolverType_Multigrid),INTENT(INOUT) :: solver
      TYPE(ParamType),INTENT(IN) :: Params
      CLASS(MatrixType),POINTER,INTENT(INOUT),OPTIONAL :: A
      CLASS(ParamType),POINTER :: pListPtr
      TYPE(ParamType) :: validParams,matPList,vecxPList,vecbPList
      ! local variables
      INTEGER(SIK) :: n,num_eqns,nx,ny,nz
      INTEGER(SIK) :: iLevel
      INTEGER(SIK) :: TPLType
      INTEGER(SIK) :: matType,matEngine
      INTEGER(SIK) :: MPI_Comm_ID,numberOMP
      LOGICAL(SBK) :: manuallySetLevelInfo
      CHARACTER(LEN=256) :: timerName
#ifdef FUTILITY_HAVE_PETSC
      PetscErrorCode :: iperr
#else
      CALL eLinearSolverType%raiseError(modName//"::"//myName//" - "// &
        "For now, LinearSolverType_Multigrid requires PETSc enabled.")
#endif
      !Check to set up required and optional param lists.
      IF(.NOT.LinearSolverType_Paramsflag) CALL LinearSolverType_Declare_ValidParams()

      !Validate against the reqParams and OptParams
      validParams=Params
      CALL validParams%validate(LinearSolverType_reqParams)

      !Pull LS data from the parameter list
      TPLType=-1
      MPI_Comm_ID=-1
      matType=-1
      matEngine=-1
      timerName=''
      numberOMP=-1
      CALL validParams%get('LinearSolverType->TPLType',TPLType)
      CALL validParams%get('LinearSolverType->MPI_Comm_ID',MPI_Comm_ID)
      CALL validParams%get('LinearSolverType->timerName',timerName)
      CALL validParams%get('LinearSolverType->matType',matType)
      CALL validParams%add('LinearSolverType->A->MatrixType->matType',matType)
      CALL validParams%get('LinearSolverType->numberOMP',numberOMP)
      ! pull data for matrix and vector parameter lists
      CALL validParams%get('LinearSolverType->A->MatrixType',pListPtr)
      matPList=pListPtr
      CALL validParams%get('LinearSolverType->x->VectorType',pListPtr)
      vecxPList=pListPtr
      CALL validParams%get('LinearSolverType->b->VectorType',pListPtr)
      vecbPList=pListPtr
      !add mpi communicator to parameter lists
      CALL matPList%add('MatrixType->MPI_Comm_ID',MPI_Comm_ID)
      CALL vecxPList%add('VectorType->MPI_Comm_ID',MPI_Comm_ID)
      CALL vecbPList%add('VectorType->MPI_Comm_ID',MPI_Comm_ID)
      !pull size from source vector
      CALL validParams%get('LinearSolverType->b->VectorType->n',n)

      CALL validParams%clear()

      !Initialize parallel environments based on input
      IF(MPI_Comm_ID /= -1) CALL solver%MPIparallelEnv%init(MPI_Comm_ID)
      IF(numberOMP > 0) CALL solver%OMPparallelEnv%init(numberOMP)

      IF(TPLType /= PETSC) THEN
        CALL eLinearSolverType%raiseError(modName//"::"//myName//" - "// &
          "For now, LinearSolverType_Multigrid only works with PETSC.")
      ENDIF

      solver%solverMethod=MULTIGRID

      IF(.NOT.solver%isInit) THEN
        solver%info=0
        IF(TPLType == PETSC) THEN
#ifdef FUTILITY_HAVE_PETSC
          solver%TPLType=PETSC
          matEngine=VM_PETSC

          !Should be irrelevant if using PETSc:
          solver%PCTypeName='NOPC'
          solver%pciters=0
          solver%pcsetup=0

          CALL matPList%add("MatrixType->engine",matEngine)
          ! allocate and initialize matrix (A)
          CALL MatrixFactory(solver%A, matPList)
          IF(PRESENT(A)) A=>solver%A

          CALL vecxPList%add('VectorType->engine',matEngine)
          CALL VectorFactory(solver%X, vecxPlist)
          CALL vecbPList%add('VectorType->engine',matEngine)
          CALL VectorFactory(solver%b, vecbPlist)


          CALL KSPCreate(solver%MPIparallelEnv%comm,solver%ksp,iperr)
          SELECTTYPE(A=>solver%A); TYPE IS(PETScMatrixType)
#if ((PETSC_VERSION_MAJOR>=3) && (PETSC_VERSION_MINOR>=5))
            CALL KSPSetOperators(solver%ksp,A%a,A%a,iperr)
#else
            CALL KSPSetOperators(solver%ksp,A%a,A%a, &
              DIFFERENT_NONZERO_PATTERN,iperr)
#endif
#endif
          ENDSELECT

        ENDIF

        !assign values to solver
        CALL solver%SolveTime%setTimerName(timerName)
        solver%isInit=.TRUE.
        solver%isMultigridSetup=.FALSE.

        !Figure out coarsening scheme:
        manuallySetLevelInfo=.FALSE.
        !To use this option, one must manually set solver%level_info and
        !  solver%nLevels
        IF(Params%has('LinearSolverType->manuallySetLevelInfo')) THEN
          CALL Params%get('LinearSolverType->manuallySetLevelInfo', &
                          manuallySetLevelInfo)
        ENDIF
        IF(.NOT. manuallySetLevelInfo) THEN
          CALL Params%get('LinearSolverType->Multigrid->nx',nx)
          CALL Params%get('LinearSolverType->Multigrid->ny',ny)
          CALL Params%get('LinearSolverType->Multigrid->nz',nz)
          CALL Params%get('LinearSolverType->MPI_Comm_ID',MPI_Comm_ID)
          CALL Params%get('LinearSolverType->Multigrid->num_eqns',num_eqns)

          !Number of levels required to reduce down to ~5*num_eqns unknowns per processor:
          solver%nLevels=FLOOR(log(MAX(nx-1,ny-1,nz-1)/ &
                solver%MPIParallelEnv%nproc/5.0_SRK)/log(2.0_SRK))+1
          solver%nLevels=MIN(solver%nLevels,max_levels)
          solver%nLevels=MAX(1,solver%nLevels)
          IF(solver%nLevels < 2) &
              CALL eLinearSolverType%raiseDebug(modName//"::"//myName//" - "// &
                     'The grid is too small to coarsen, using multigrid with '// &
                     ' only 1 level!')
          ALLOCATE(solver%level_info(4,solver%nLevels))
          solver%level_info(:,solver%nLevels)=(/num_eqns,nx,ny,nz/)
          DO iLevel=solver%nLevels-1,1,-1
          !Setup the interpolation operator:
            IF(nx > 3) THEN
              nx=nx/2+1
            ELSEIF(nx == 3) THEN
              nx=1
            ENDIF
            IF(ny > 3) THEN
              ny=ny/2+1
            ELSEIF(ny == 3) THEN
              ny=1
            ENDIF
            IF(nz > 3) THEN
              nz=nz/2+1
            ELSEIF(nz == 3) THEN
              nz=1
            ENDIF
            solver%level_info(:,iLevel)=(/num_eqns,nx,ny,nz/)
          ENDDO !iLevel
        ELSE
          CALL Params%get('LinearSolverType->Multigrid->nLevels',solver%nLevels)
          ALLOCATE(solver%level_info(4,solver%nLevels))
          CALL Params%get('LinearSolverType->Multigrid->level_info',solver%level_info)
        ENDIF !manuallySetLevelInfo

        !Sanity check:
        IF(PRODUCT(solver%level_info(:,solver%nLevels)) /= n) THEN
            CALL eLinearSolverType%raiseError(modName//"::"//myName//" - "// &
                   'number of unknowns (n) does not match provided '// &
                   'nx,ny,nz,num_eqns')
        ENDIF

        ALLOCATE(solver%interpMats(solver%nLevels-1))
      ELSE
        CALL eLinearSolverType%raiseError('Incorrect call to '// &
          modName//'::'//myName//' - LinearSolverType already initialized')
      ENDIF
      CALL vecbPList%clear()
      CALL vecxPList%clear()
      CALL matPList%clear()
    ENDSUBROUTINE init_LinearSolverType_Multigrid
!
!-------------------------------------------------------------------------------
!> @brief Initialize and preallocate memory for PETSc interpolation matrices
!>
!> @param solver The linear solver to act on
!> @param iLevel The matrix we are allocating interpolates from grid iLevel-1 
!>        to grid iLevel
!> @param dnnz dnnz(i) must provide the number of nonzero columns local to the
!>             processor in local row i
!> @param onnz onnz(i) must provide the number of nonzero columns external to
!>             the processor in local row i
!>
    SUBROUTINE preAllocPETScInterpMat_LinearSolverType_Multigrid(solver, &
       iLevel,dnnz,onnz)
      CHARACTER(LEN=*),PARAMETER :: myName='preAllocPETScInterpMat_LinearSolverType_Multigrid'
      CLASS(LinearSolverType_Multigrid),INTENT(INOUT) :: solver
      INTEGER(SIK),INTENT(IN) :: iLevel,dnnz(:),onnz(:)
      INTEGER(SIK) :: nx,ny,nz,num_eqns,n
      INTEGER(SIK) :: nx_old,ny_old,nz_old,num_eqns_old,n_old

      TYPE(ParamType) :: matPList
      CLASS(MatrixType),POINTER :: interpmat => NULL()
      
      IF(solver%isInit) THEN
        num_eqns=solver%level_info(1,iLevel)
        nx=solver%level_info(2,iLevel)
        ny=solver%level_info(3,iLevel)
        nz=solver%level_info(4,iLevel)
        n=nx*ny*nz*num_eqns

        num_eqns_old=solver%level_info(1,iLevel+1)
        nx_old=solver%level_info(2,iLevel+1)
        ny_old=solver%level_info(3,iLevel+1)
        nz_old=solver%level_info(4,iLevel+1)
        n_old=nx_old*ny_old*nz_old*num_eqns_old

        CALL matPList%clear()
        CALL matPList%add('MatrixType->matType',SPARSE)
        CALL matPList%add('MatrixType->engine',VM_PETSC)
        CALL matPList%add('MatrixType->MPI_Comm_ID',solver%MPIparallelEnv%comm)
        CALL matPList%add('MatrixType->isSym',.FALSE.)
        CALL matPList%add('MatrixType->n',n_old)
        CALL matPList%add('MatrixType->m',n)
        !TODO fix this in parallel:
        CALL matPList%add('MatrixType->nlocal',n_old)
        CALL matPList%add('MatrixType->mlocal',n)
        CALL matPList%add('MatrixType->onnz',onnz)
        CALL matPList%add('MatrixType->dnnz',dnnz)
        !CALL matPList%add('MatrixType->nnz',SUM(dnnz)+SUM(onnz))
        CALL MatrixFactory(interpmat,matPList)

        !Store this matrix object:
        SELECTTYPE(interpmat); TYPE IS(PETScMatrixType)
          solver%interpMats(iLevel)=interpmat
        ENDSELECT

        NULLIFY(interpmat)
      ELSE
        CALL eLinearSolverType%raiseError('Incorrect call to '// &
          modName//'::'//myName//' - LinearSolverType must be initialized')
      ENDIF

      CALL matPList%clear()

      
    ENDSUBROUTINE preAllocPETScInterpMat_LinearSolverType_Multigrid
!
!-------------------------------------------------------------------------------
!> @brief Setup the PCMG environment in PETSc, finalize the interpolation operators
!>
!> @param solver The linear solver to act on
!> @param Params the parameter list
!>
    SUBROUTINE setupPETScMG_LinearSolverType_Multigrid(solver,Params)
      CHARACTER(LEN=*),PARAMETER :: myName='setupPETScMG_LinearSolverType_Multigrid'
      CLASS(LinearSolverType_Multigrid),INTENT(INOUT) :: solver
      TYPE(ParamType),INTENT(IN) :: Params
      INTEGER(SIK) :: iLevel
      INTEGER(SIK) :: nx,ny,nz
#ifdef FUTILITY_HAVE_PETSC
      INTEGER(SIK),ALLOCATABLE :: tmpint_arr(:) !ZZZZ

      KSP :: ksp_temp
      PC :: pc_temp
      PetscErrorCode  :: iperr
      Mat :: mat_temp
#else
      CALL eLinearSolverType%raiseError(modName//"::"//myName//" - "// &
        "This subroutine should only be called with PETSc.")
#endif
      IF(solver%TPLType /= PETSC) &
        CALL eLinearSolverType%raiseError(modName//"::"//myName//" - "// &
          "This subroutine should only be called with PETSc.")

      IF(solver%isMultigridSetup) &
          CALL eLinearSolverType%raiseError(modName//"::"//myName//" - "// &
                 'Multigrid linear system is already setup!')

#ifdef FUTILITY_HAVE_PETSC
      !KSPRICHARDSON+PCMG = Multigrid linear solver, not multigrid precon.
      CALL KSPSetType(solver%ksp,KSPRICHARDSON,iperr)
      CALL KSPGetPC(solver%ksp,solver%pc,iperr)
      CALL PCSetType(solver%pc,PCMG,iperr)

      !For now, only Galerkin coarse grid operators are supported.
      !  Galerkin means A_c = R*A*I
      CALL PCMGSetGalerkin(solver%pc,PETSC_TRUE,iperr)
      CALL KSPSetInitialGuessNonzero(solver%ksp,PETSC_TRUE,iperr)

      !Set # of levels:
      CALL PCMGSetLevels(solver%pc,solver%nLevels,PETSC_NULL_OBJECT,iperr) !TODO use some sort of mpi thing here?

      !The following options are applied to all blocks of the block Jacobi
      ! smoother on all MG levels except the coarsest level.
      !Solve each block with GS:
      ! KSPRICHARDSON+SOR with omega=1 --> Gauss-Seidel
      ! The mg_levels_ prefix specifies that it's for the MG smoother
      ! mg_levels does not include the coarsest level
      ! the sub_ indicates it's for each block
      CALL PetscOptionsSetValue(PETSC_NULL_OBJECT, &
              "-mg_levels_sub_ksp_type","richardson",iperr)
      CALL PetscOptionsSetValue(PETSC_NULL_OBJECT, &
              "-mg_levels_sub_pc_type","sor",iperr)
      CALL PetscOptionsSetValue(PETSC_NULL_OBJECT, &
              "-mg_levels_sub_ksp_initial_guess_nonzero","true",iperr)
      !Only one "richardson iteration" (with possibly many SOR iterations):
      CALL PetscOptionsSetValue(PETSC_NULL_OBJECT, &
          "-mg_levels_sub_ksp_max_it","1",iperr)
      !For some reason it iterates forever when it's a 1x1 block:
      IF(solver%level_info(1,solver%nLevels) == 1) THEN
        CALL PetscOptionsSetValue(PETSC_NULL_OBJECT, &
              "-mg_levels_sub_pc_sor_its","1",iperr)
      ELSE IF(ANY(solver%level_info(1,:) == 1)) THEN
        CALL eLinearSolverType%raiseError(modName//"::"//myName//" - "// &
          "The current setup with PETSc does not allow for coarsening from"// &
          " multiple equations to 1 equation.  If you need this feature, "// &
          "consider altering this subroutine.  It is likely not too "// &
          "difficult to do so.")
      ELSE
        CALL PetscOptionsSetValue(PETSC_NULL_OBJECT, &
              "-mg_levels_sub_pc_sor_its","1",iperr)
        CALL PetscOptionsSetValue(PETSC_NULL_OBJECT, &
              "-mg_levels_sub_pc_sor_lits","10",iperr)
        !ZZZZ might want to change this value later
      ENDIF

      DO iLevel=solver%nLevels-1,1,-1
        !Set the smoother:
        CALL PCMGGetSmoother(solver%pc,iLevel,ksp_temp,iperr)

        !Block Jacobi smoother:
        !KSPRICHARDSON+PCBJACOBI=block jacobi
        CALL KSPSetType(ksp_temp,KSPRICHARDSON,iperr)
        CALL KSPGetPC(ksp_temp,pc_temp,iperr)
        CALL PCSetType(pc_temp,PCBJACOBI,iperr)
        CALL KSPSetInitialGuessNonzero(ksp_temp,PETSC_TRUE,iperr)

        !Set number of blocks (i.e., # of spatial points):
        nx=solver%level_info(2,iLevel+1)
        ny=solver%level_info(3,iLevel+1)
        nz=solver%level_info(4,iLevel+1)
        ALLOCATE(tmpint_arr(nx*ny*nz))
        tmpint_arr=solver%level_info(1,iLevel+1)
        CALL PCBJacobiSetTotalBlocks(pc_temp,nx*ny*nz,tmpint_arr,iperr)
        DEALLOCATE(tmpint_arr)

        CALL PCSetFromOptions(pc_temp,iperr)

        !Set the interpolation operator:
        CALL solver%interpMats(iLevel)%assemble()
        CALL PCMGSetInterpolation(solver%pc,iLevel,solver%interpMats(iLevel)%a,iperr)
      ENDDO

      !Coarsest smoother is GMRES with block Jacobi preconditioner:
      CALL PCMGGetSmoother(solver%pc,0,ksp_temp,iperr)
      CALL KSPSetType(ksp_temp,KSPGMRES,iperr)
      CALL KSPGetPC(ksp_temp,pc_temp,iperr)
      CALL PCSetType(pc_temp,PCBJACOBI,iperr)
      CALL KSPSetInitialGuessNonzero(ksp_temp,PETSC_TRUE,iperr)
#endif
      solver%isMultigridSetup=.TRUE.

    ENDSUBROUTINE setupPETScMG_LinearSolverType_Multigrid
!
!-------------------------------------------------------------------------------
!> @brief Clears the Multigrid Linear Solver Type
!> @param solver The linear solver to act on
!>
!> This routine clears the data spaces for the iterative linear solver.
!>
    SUBROUTINE clear_LinearSolverType_Multigrid(solver)
      CLASS(LinearSolverType_Multigrid),INTENT(INOUT) :: solver

      INTEGER(SIK) :: iLevel

#ifdef FUTILITY_HAVE_PETSC
      PetscErrorCode :: iperr

      IF(solver%isMultigridSetup) THEN
        DO iLevel=1,solver%nLevels-1
          CALL solver%interpMats(iLevel)%clear()
        ENDDO
      ENDIF
#endif

      solver%isMultigridSetup=.FALSE.
      IF(ALLOCATED(solver%level_info)) DEALLOCATE(solver%level_info)
      IF(ALLOCATED(solver%level_info_local)) DEALLOCATE(solver%level_info_local)
      IF(ALLOCATED(solver%interpMats)) DEALLOCATE(solver%interpMats)
      solver%nLevels=1_SIK

      CALL solver%LinearSolverType_Iterative%clear()

    ENDSUBROUTINE clear_LinearSolverType_Multigrid

ENDMODULE LinearSolverTypes_Multigrid