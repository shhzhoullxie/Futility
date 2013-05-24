!++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++!
!                              Copyright (C) 2012                              !
!                   The Regents of the University of Michigan                  !
!              MPACT Development Group and Prof. Thomas J. Downar              !
!                             All rights reserved.                             !
!                                                                              !
! Copyright is reserved to the University of Michigan for purposes of          !
! controlled dissemination, commercialization through formal licensing, or     !
! other disposition. The University of Michigan nor any of their employees,    !
! makes any warranty, express or implied, or assumes any liability or          !
! responsibility for the accuracy, completeness, or usefulness of any          !
! information, apparatus, product, or process disclosed, or represents that    !
! its use would not infringe privately owned rights. Reference herein to any   !
! specific commercial products, process, or service by trade name, trademark,  !
! manufacturer, or otherwise, does not necessarily constitute or imply its     !
! endorsement, recommendation, or favoring by the University of Michigan.      !
!++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++!
!> @brief Utility module to replicate some TAU interfaces when TAU is not
!>        available. Only measures time and number of calls.
!>
!> This module makes the following interfaces from the TAU API available:
!>  - @c TAU_PROFILE_INIT - must be called before any of the other routines
!>  - @c TAU_PROFILE_TIMER - defines a static timer
!>  - @c TAU_PROFILE_START - starts profiling a section
!>  - @c TAU_PROFILE_STOP - stops profiling a section (must be called after 
!>       @c TAU_PROFILE_START)
!>  - @c TAU_PROFILE_EXIT - stops all profiling and writes profiling data to
!>                          disk
!>
!> These can be used essentially the same way as they would be used by TAU. The
!> profiling capability here can be used to profile sections of code in serial,
!> MPI, OpenMP, or OpenMP/MPI applications. However, there are several caveats
!> the user must be aware of.
!>
!> @par First:
!> Automatic source instrumentation is not available, so using the 
!> profiling capability requires hand instrumentation of the source. When
!> instrumenting the source the <TT>USE TAU_Stubs</TT> statement must be
!> within the scope of the procedure.
!>
!> @par Second:
!> The @ref TAU_Stubs::TAU_PROFILE_EXIT "TAU_PROFILE_EXIT", routine must be
!> called prior to the halt of execution else no profile data is written to 
!> disk. 
!>
!> @par Third:
!> Applies only to situations where the application uses OpenMP. In
!> OpenMP applications it is @b ESSENTIAL that the following be added
!> to any @c PARALLEL construct:
!> @code
!> !$OMP SHARED(TauStubLibData)
!> @endcode
!>
!> Furthermore, there are some important subtleties to understand about the
!> profilers. When a profiler is defined with @ref TAU_Stubs::TAU_PROFILE_TIMER
!> "TAU_PROFILE_TIMER" it is thread dependent. The return argument @c profileID
!> essentially contains two indices: the thread on which the profiler was defined
!> and the number of profilers defined before it. This data functions as
!> the profiler database lookup key. When outside of @c PARALLEL
!> constructs, the master thread will be able to access any of the profilers, but
!> the correct profiler key must be passed to do so. Therefore, the @c profileID
!> return argument will need to persist with the correct value after the parallel
!> region has ended.
!> 
!> It gets slightly more complicated. When inside a parallel region, only those
!> threads for which a specific profiler is defined can access that profiler.
!> Note here it is therefore important that the @c profileID return argument
!> persist with the correct value into the parallel region. To do this it is
!> recommended that any profilerID variables be given the @c FIRSTPRIVATE data
!> scope.
!>
!> Some specific examples are provided below to illustrate the usage.
!>
!> @par Fourth:
!> The data is exported into the TAU profile format, and is therefore viewable
!> in ParaProf. All times reported have identical values for exclusive and
!> inclusive metrics. The edited times are strictly inclusive. No child calls
!> are recorded. All measurements are put into the "TAU_STUBS" group. The file
!> metadata is also extremely limited and only includes the
!> "TAU_PROFILE_FORMAT", "TAU Version", and a new meta-data element that reports
!> the estimated overhead from using these timers. The TAU Version is listed as
!> "TAU Stubs Library (MPACT)".
!>
!> @par Module Dependencies
!>  - @ref IntrType "IntrType": @copybrief IntrType
!>  - @ref Strings "Strings": @copybrief Strings
!>  - @ref Times "Times": @copybrief Times
!>
!> @par EXAMPLES
!> @code
!> PROGRAM TestTauStubs
!> 
!>   USE TAU_Stubs
!>   IMPLICIT NONE
!>
!>   
!> END PROGRAM
!> @endcode
!>
!> @author Brendan Kochunas
!>   @date 02/06/2013
!>
!++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++!
MODULE TAU_Stubs

!$ USE OMP_LIB
  USE ISO_FORTRAN_ENV
  USE ISO_C_BINDING
  USE IntrType
  USE Strings
  USE Times
  USE IO_Strings
  IMPLICIT NONE
  PRIVATE
  
#ifdef HAVE_MPI
  INCLUDE 'mpif.h'
#endif

#ifdef HAVE_PAPI
  INCLUDE 'f90papi.h'
#endif

!
!List of public members
  PUBLIC :: TauStubLibData
  PUBLIC :: TAU_PROFILE_INIT
  PUBLIC :: TAU_PROFILE_TIMER
  PUBLIC :: TAU_PROFILE_START
  PUBLIC :: TAU_PROFILE_STOP
  PUBLIC :: TAU_PROFILE_EXIT
  PUBLIC :: TAUSTUB_CHECK_MEMORY
  
  !> @brief Derived type for defines a basic profiler.
  !>
  !> A profiler is given a name and keeps track of the execution time of
  !> a region and the number of times the start/stop operations were
  !> called for the specific profiler.
  !>
  TYPE :: ProfilerType
    INTEGER(SLK) :: num_calls=0
    LOGICAL(SBK) :: isStart=.FALSE.
    LOGICAL(SBK) :: inOMP=.FALSE.
    REAL(SDK) :: ompTime=0.0_SDK
    TYPE(StringType) :: name
    TYPE(TimerType) :: timer
    INTEGER(C_LONG_LONG),ALLOCATABLE :: tmpCounts(:,:)
    REAL(SDK),ALLOCATABLE :: papiCounts(:)
    TYPE(ProfilerType),POINTER :: nextProfiler => NULL()
  ENDTYPE ProfilerType
  
  !> @brief A type for containing an array of scalar pointers for profilers
  !>
  !> Essentially a database.
  !>
  TYPE :: ProfilerDBType
    TYPE(ProfilerType),POINTER :: profiler => NULL()
  ENDTYPE ProfilerDBType
  
  !> @brief Type for storing all the profiling data amongst processes
  !>
  !> This is used to define one variable which is a singleton object
  !> of this type.
  !>
  TYPE :: TauStubModData
    LOGICAL(SBK) :: isInit=.FALSE.
    INTEGER(C_INT) :: PAPIEventSetHandle=-1
    INTEGER(SIK) :: nMetrics=-1
    INTEGER(SIK) :: rankWorld=-1
    INTEGER(SLK) :: nthreads=-1
    REAL(SDK) :: tOverhead=-1.0_SDK
    REAL(SDK),ALLOCATABLE :: metricOverhead(:)
    INTEGER(SIK),POINTER :: nProfiles(:)
    TYPE(ProfilerDBType),POINTER :: threadProfilesDB(:)
  ENDTYPE TauStubModData
  
  !> Singleton object containing all the profilers and profiling data for the 
  !> given executable.
  TYPE(TauStubModData),SAVE :: TauStubLibData
!
!===============================================================================
  CONTAINS
!
!-------------------------------------------------------------------------------
!> @brief Initializes module global variables
!>
!> Determines the number of threads and the number of MPI processors of the
!> execution environment. Allocates space for profilers.
!>
    SUBROUTINE TAU_PROFILE_INIT()
      INTEGER(SIK) :: isinit,mpierr
      INTEGER(C_INT) :: perr

!$OMP SINGLE
      IF(.NOT.TauStubLibData%isInit) THEN
  
#ifdef HAVE_MPI
        CALL MPI_Initialized(isinit,mpierr)
        IF(isinit == 0) CALL MPI_Init(mpierr)
        CALL MPI_Comm_rank(MPI_COMM_WORLD,TauStubLibData%rankWorld,mpierr)
#else
        TauStubLibData%rankWorld=0
#endif

        TauStubLibData%nthreads=1
!$      TauStubLibData%nthreads=OMP_GET_MAX_THREADS()
        
        ALLOCATE(TauStubLibData%threadProfilesDB(TauStubLibData%nthreads))
        ALLOCATE(TauStubLibData%nProfiles(TauStubLibData%nthreads))
        TauStubLibData%nProfiles=0
        
#ifdef HAVE_PAPI
        perr=PAPI_VER_CURRENT
        CALL PAPIF_library_init(perr)
!$      CALL PAPIF_thread_init(OMP_GET_THREAD_NUM,perr)
        CALL Set_PAPI_Metrics()
#endif
        
        !Determine overhead
        CALL EstimateOverhead()
      ENDIF
      TauStubLibData%isInit=.TRUE.
!$OMP END SINGLE
!$OMP BARRIER
    ENDSUBROUTINE TAU_PROFILE_INIT
!
!-------------------------------------------------------------------------------
!> @brief Initializes a profiler
!> @param profileID the profiler ID
!> @param profileName the name to give the region or event that is to be
!>        profiled.
!>
    SUBROUTINE TAU_PROFILE_TIMER(profileID,name)
      INTEGER(SIK),INTENT(INOUT) :: profileID(2)
      CHARACTER(LEN=*),INTENT(IN) :: name
      INTEGER(SIK) :: tid,it
      TYPE(ProfilerType),POINTER :: newThreadProfiler
  
      IF(ALL(profileID == 0) .AND. TauStubLibData%isInit) THEN
        tid=1
!$      tid=OMP_GET_THREAD_NUM()+1
        IF(ASSOCIATED(TauStubLibData%threadProfilesDB(tid)%profiler)) THEN
          newThreadProfiler => TauStubLibData%threadProfilesDB(tid)%profiler
          DO it=1,TauStubLibData%nProfiles(tid)-1
            newThreadProfiler => newThreadProfiler%nextProfiler
          ENDDO
          ALLOCATE(newThreadProfiler%nextProfiler)
          newThreadProfiler => newThreadProfiler%nextProfiler
        ELSE
          ALLOCATE(TauStubLibData%threadProfilesDB(tid)%profiler)
          newThreadProfiler => TauStubLibData%threadProfilesDB(tid)%profiler
        ENDIF
        TauStubLibData%nProfiles(tid)=TauStubLibData%nProfiles(tid)+1
        newThreadProfiler%name=TRIM(ADJUSTL(name))
        IF(TauStubLibData%nMetrics > 0) THEN
          ALLOCATE(newThreadProfiler%papiCounts(TauStubLibData%nMetrics))
          ALLOCATE(newThreadProfiler%tmpCounts(TauStubLibData%nMetrics,2))
          newThreadProfiler%papiCounts=0.0_SDK
          CALL newThreadProfiler%timer%ResetTimer()
        ENDIF
        profileID(1)=tid
        profileID(2)=TauStubLibData%nProfiles(tid)
      ENDIF
    ENDSUBROUTINE TAU_PROFILE_TIMER
!
!-------------------------------------------------------------------------------
!> @brief Starts measurements for a profiler
!> @param profileID the profiler ID
!>
    SUBROUTINE TAU_PROFILE_START(profileID)
      INTEGER(SIK),INTENT(IN) :: profileID(2)
      LOGICAL(SBK) :: inOMP
      INTEGER(SIK) :: it,tid
      INTEGER(C_INT) :: perr
      INTEGER(C_LONG_LONG) :: ptime
      TYPE(ProfilerType),POINTER :: activeThreadProfiler
      
      IF(profileID(1) > 0 .AND. profileID(1) <= TauStubLibData%nthreads) THEN
!       Profilers are thread dependent, so only access profilers initialized on
!       other threads when NOT in a parallel region.
!
        tid=1
        inOMP=.FALSE.
!$      inOMP=OMP_IN_PARALLEL()
!$      tid=OMP_GET_THREAD_NUM()+1
!$      IF(.NOT.inOMP .OR. (inOMP .AND. profileID(1) == tid)) THEN
          tid=profileID(1)
          IF(profileID(2) > 0 .AND. profileID(2) <= TauStubLibData%nProfiles(tid)) THEN
            activeThreadProfiler => TauStubLibData%threadProfilesDB(tid)%profiler
            DO it=1,profileID(2)-1
              activeThreadProfiler => activeThreadProfiler%nextProfiler
            ENDDO
            activeThreadProfiler%isStart=.TRUE.
            
#ifdef HAVE_PAPI
            IF(TauStubLibData%nMetrics > 0) THEN
              CALL PAPIF_read(TauStubLibData%PAPIEventSetHandle, &
                activeThreadProfiler%tmpCounts(:,1),perr)
            ENDIF
            CALL PAPIF_get_real_nsec(ptime)
            activeThreadProfiler%ompTime=REAL(ptime,SDK)
#else
            activeThreadProfiler%inOMP=inOMP
            IF(.NOT.activeThreadProfiler%inOMP) THEN
              CALL activeThreadProfiler%timer%tic()
            ELSE
!$            activeThreadProfiler%ompTime=OMP_GET_WTIME()
            ENDIF
#endif
          ENDIF
!$      ENDIF
      ENDIF
    ENDSUBROUTINE TAU_PROFILE_START
!
!-------------------------------------------------------------------------------
!> @brief Stops measurements for a profiler
!> @param profileID the profiler ID
!>
    SUBROUTINE TAU_PROFILE_STOP(profileID)
      INTEGER(SIK),INTENT(IN) :: profileID(2)
      INTEGER(SIK) :: it,tid
      INTEGER(C_INT) :: perr
      INTEGER(C_LONG_LONG) :: ptime
      TYPE(ProfilerType),POINTER :: activeThreadProfiler
  
      IF(profileID(1) > 0 .AND. profileID(1) <= TauStubLibData%nthreads) THEN
        tid=profileID(1)
        activeThreadProfiler => TauStubLibData%threadProfilesDB(tid)%profiler
        IF(profileID(2) > 0 .AND. profileID(2) <= TauStubLibData%nProfiles(tid)) THEN
          DO it=1,profileID(2)-1
            activeThreadProfiler => activeThreadProfiler%nextProfiler
          ENDDO
          IF(activeThreadProfiler%isStart) THEN
#ifdef HAVE_PAPI
            CALL PAPIF_get_real_nsec(ptime)
            IF(TauStubLibData%nMetrics > 0) THEN
              CALL PAPIF_read(TauStubLibData%PAPIEventSetHandle, &
                activeThreadProfiler%tmpCounts(:,2),perr)
              activeThreadProfiler%papiCounts=activeThreadProfiler%papiCounts+ &
                REAL(activeThreadProfiler%tmpCounts(:,2)- &
                  activeThreadProfiler%tmpCounts(:,1),SDK)
            ENDIF
            activeThreadProfiler%timer%elapsedTime= &
              activeThreadProfiler%timer%elapsedTime+(REAL(ptime,SDK)- &
                activeThreadProfiler%ompTime)*1.0e-9_SDK
#else
          
            IF(.NOT.activeThreadProfiler%inOMP) THEN
              CALL activeThreadProfiler%timer%toc() !2 Flops on each call
            ELSE
!$            activeThreadProfiler%timer%elapsedTime= &
!$              activeThreadProfiler%timer%elapsedTime+OMP_GET_WTIME()- &
!$                activeThreadProfiler%ompTime
            ENDIF
#endif

            activeThreadProfiler%isStart=.FALSE.
            activeThreadProfiler%num_calls=activeThreadProfiler%num_calls+1
          ENDIF
        ENDIF
      ENDIF
    ENDSUBROUTINE TAU_PROFILE_STOP
!
!-------------------------------------------------------------------------------
    SUBROUTINE TAUSTUB_CHECK_MEMORY()
#ifdef HAVE_PAPI
      LOGICAL(SBK),SAVE :: lfirst=.TRUE.
      INTEGER(C_LONG_LONG) :: values(12),memUsage(4)
      INTEGER(C_INT) :: perr
      
      
      CALL PAPIF_get_dmem_info(values,perr)
      memUsage(1)=values(PAPIF_DMEM_VMSIZE)
      memUsage(2)=values(PAPIF_DMEM_RESIDENT)
      memUsage(3)=values(PAPIF_DMEM_HIGH_WATER)
      memUsage(4)=values(PAPIF_DMEM_HEAP)
      WRITE(OUTPUT_UNIT,*)
      WRITE(OUTPUT_UNIT,*) '######## TAUSTUB_CHECK_MEMORY: Message Begin'
      WRITE(OUTPUT_UNIT,*) '     Virtual    |    Resident    |    HighWater   |      Heap'
      WRITE(OUTPUT_UNIT,*) ' '//TRIM(getMemChar(memUsage(1)))//' | '// &
        TRIM(getMemChar(memUsage(2)))//' | '//TRIM(getMemChar(memUsage(3))) &
          //' | '//TRIM(getMemChar(memUsage(4)))
      WRITE(OUTPUT_UNIT,*) '######## TAUSTUB_CHECK_MEMORY: Message End'
      WRITE(OUTPUT_UNIT,*)
#endif
    ENDSUBROUTINE TAUSTUB_CHECK_MEMORY
!
!-------------------------------------------------------------------------------
!> @brief Outputs all the profiler measurement data to disk and removes
!> profilers from memory. Should be called prior to exiting or stopping 
!> execution.
!>
!> When adding this to an executable it should be the last line called before
!> @c "ENDPROGRAM". Although it can be placed elsewhere if you understand what
!> you're doing. If you are running an MPI executable then you should 
!> place this call just before the call to MPI_Finalize().
!>
!> If the program terminates prior to this routine being called (e.g. because of
!> an error) then no profile data will be output.
!>
!> It may be called from inside a parallel region, and it should work ok, but
!> probably better if you don't.
!>
    SUBROUTINE TAU_PROFILE_EXIT()
      
      LOGICAL(SBK) :: isopen
      INTEGER(SIK) :: funit,i
      INTEGER(SLK) :: it
      TYPE(StringType),ALLOCATABLE :: dirnames(:),eventNames(:)

!$OMP BARRIER
!
!Create directories for profiles
#ifdef HAVE_PAPI
      CALL CreateProfDirs(dirnames,eventNames)
#else
      ALLOCATE(dirnames(0:0))
      ALLOCATE(eventNames(0:0))
      dirnames(0)='.'
      eventNames(0)='LINUX_TIMERS'
#endif
!$OMP MASTER
!
!Get an open unit number for the file
      funit=723
      isopen=.FALSE.
      INQUIRE(UNIT=funit,OPENED=isopen)
      DO WHILE(isopen)
        funit=funit+1
        INQUIRE(UNIT=funit,OPENED=isopen)
      ENDDO
      
      DO i=0,UBOUND(dirnames,DIM=1)
        CALL Write_Profile_metric(funit,CHAR(dirnames(i)),eventNames,i)
      ENDDO
!
!Destroy all the profilers.
      DO it=1,TauStubLibData%nthreads
        CALL Clear_ProfilerType(TauStubLibData%threadProfilesDB(it)%profiler)
      ENDDO
      DEALLOCATE(TauStubLibData%nProfiles)
      TauStubLibData%nthreads=-1
      TauStubLibData%nMetrics=-1
      TauStubLibData%rankWorld=-1
      TauStubLibData%tOverhead=-1.0_SDK
      TauStubLibData%isInit=.FALSE.
      
#ifdef HAVE_PAPI
      CALL PAPIF_shutdown()
#endif
!$OMP END MASTER
    ENDSUBROUTINE TAU_PROFILE_EXIT
!
!-------------------------------------------------------------------------------
    SUBROUTINE Write_Profile_metric(funit,outdir,metric_name,i)
      INTEGER(SIK),INTENT(IN) :: funit
      CHARACTER(LEN=*),INTENT(IN) :: outdir
      TYPE(StringType),INTENT(IN) :: metric_name(0:)
      INTEGER(SIK),INTENT(IN) :: i
      
      CHARACTER(LEN=16) :: rankstr,tidstr,tmpIstr
      CHARACTER(LEN=20) :: tmpRstr
      INTEGER(SIK) :: ip,ierr,j
      INTEGER(SLK) :: it
      TYPE(StringType) :: fname,tline
      TYPE(ProfilerType),POINTER :: activeProfiler
      
      WRITE(rankstr,'(i16)') TauStubLibData%rankWorld
!
!Loop over threads and write files
      DO it=1,TauStubLibData%nthreads
        WRITE(tidstr,'(i16)') it-1
        fname='profile.'//TRIM(ADJUSTL(rankstr))//'.0.'//TRIM(ADJUSTL(tidstr))
        IF(TauStubLibData%nProfiles(it) > 0) THEN
          OPEN(UNIT=funit,ACCESS='SEQUENTIAL',FORM='FORMATTED',ACTION='WRITE', &
            STATUS='REPLACE',FILE=outdir//SLASH//CHAR(fname),IOSTAT=ierr)
          IF(ierr == 0) THEN
!
!Write the profile data to disk
            !Header
            WRITE(tmpIstr,'(i16)') TauStubLibData%nProfiles(it)
            tline=TRIM(ADJUSTL(tmpIstr))//' templated_functions_MULTI_'// &
              CHAR(metric_name(i))
            WRITE(UNIT=funit,FMT='(a)',IOSTAT=ierr) CHAR(tline)
          
            !Metadata
            WRITE(tmpRstr,'(g9.3)') TauStubLibData%tOverhead
            tline='# Name Calls Subrs Excl Incl ProfileCalls # <metadata>'
            tline=tline//'<attribute>'// &
              '<name>Metric Name</name><value>'//CHAR(metric_name(i))// &
             '</value></attribute><attribute>'// &
              '<name>TAU Version</name><value>TAU Stub Library (MPACT)</value>'// &
             '</attribute><attribute>'// &
              '<name>Est. overhead per call</name><value>'//TRIM(ADJUSTL(tmpRstr))// &
                ' nsecs.</value>'// &
             '</attribute><attribute>'// &
#ifdef HAVE_PAPI
               '<name>PAPI Version</name><value>'//TRIM(Get_PAPI_VERSION())// &
              '</value>'//'</attribute><attribute>'// &
#endif
              '<name>TAU_PROFILE_FORMAT</name><value>profile</value>'// &
             '</attribute>'
            IF(TauStubLibData%nMetrics > 0) THEN
              DO j=1,TauStubLibData%nMetrics
                WRITE(tmpRstr,'(g11.5)') TauStubLibData%metricOverhead(j)
                tline=tline//'<attribute>'//'<name>Est. overhead per call for '// &
                  CHAR(metric_name(j))//'</name><value>'//TRIM(ADJUSTL(tmpRstr))// &
                '</value></attribute>'
              ENDDO
            ENDIF
            tline=tline//'</metadata>'
            WRITE(UNIT=funit,FMT='(a)',IOSTAT=ierr) CHAR(tline)
          
            !Write profile data (Consists of INCLUSIVE times only)
            activeProfiler => TauStubLibData%threadProfilesDB(it)%profiler
            DO ip=1,TauStubLibData%nProfiles(it)
              
              IF(activeProfiler%isStart) THEN
                !Make sure the profiler has been stopped
                CALL activeProfiler%timer%toc()
                activeProfiler%isStart=.FALSE.
                activeProfiler%num_calls=activeProfiler%num_calls+1
              ENDIF
              
              IF(i == 0) THEN
                IF(activeProfiler%timer%getTimeReal() < 0.0_SDK) THEN
                  WRITE(tmpRstr,'(g20.15)') 0.0_SDK
                ELSE
                  WRITE(tmpRstr,'(g20.15)') ((activeProfiler%timer%getTimeReal())*1.e6_SDK)
                ENDIF
              ELSE
                WRITE(tmpRstr,'(g20.15)') activeProfiler%papiCounts(i)
              ENDIF
              WRITE(tmpIstr,'(i16)') activeProfiler%num_calls
              tline='"'//CHAR(activeProfiler%name)//'" '//TRIM(ADJUSTL(tmpIstr))// &
                ' 0 '//TRIM(ADJUSTL(tmpRstr))//' '//TRIM(ADJUSTL(tmpRstr))// &
                ' 0 GROUP="TAU_STUB"'
              WRITE(UNIT=funit,FMT='(a)',IOSTAT=ierr) CHAR(tline)
              activeProfiler => activeProfiler%nextProfiler
            ENDDO
          
            !Write end of file
            WRITE(UNIT=funit,FMT='(a)',IOSTAT=ierr) '0 aggregates'
            WRITE(UNIT=funit,FMT='(a)',IOSTAT=ierr) '0 userevents'
            CLOSE(UNIT=funit,IOSTAT=ierr)
          ENDIF
        ENDIF
      ENDDO
    ENDSUBROUTINE Write_Profile_metric
!
!-------------------------------------------------------------------------------
!> @brief Recursively clears a linked list of profilers
!>
!> Not public. Should only be called by TAUSTUB_FINISH
!>
    RECURSIVE SUBROUTINE Clear_ProfilerType(thisProfiler)
      TYPE(ProfilerType),POINTER,INTENT(INOUT) :: thisProfiler
      IF(ASSOCIATED(thisProfiler)) THEN
        CALL Clear_ProfilerType(thisProfiler%nextProfiler)
        thisProfiler%name=''
        IF(ALLOCATED(thisProfiler%papiCounts)) &
          DEALLOCATE(thisProfiler%papiCounts)
        IF(ALLOCATED(thisProfiler%tmpCounts)) &
          DEALLOCATE(thisProfiler%tmpCounts)
        DEALLOCATE(thisProfiler)
      ENDIF
    ENDSUBROUTINE Clear_ProfilerType
!
!-------------------------------------------------------------------------------
#ifdef HAVE_PAPI
    SUBROUTINE Set_PAPI_metrics()
      INTEGER(SIK) :: nlen

      CALL GET_ENVIRONMENT_VARIABLE('TAU_METRICS',LENGTH=nlen)
      CALL Init_PAPI_Event_Set(nlen)
    ENDSUBROUTINE Set_PAPI_metrics
!
!-------------------------------------------------------------------------------
    SUBROUTINE Init_PAPI_Event_Set(n)
      INTEGER(SIK),INTENT(IN) :: n
      CHARACTER(LEN=n) :: TAU_METRICS
      CHARACTER(LEN=n) :: papi_metric_name
      INTEGER(SIK) :: istt,istp,nevents
      INTEGER(C_INT) :: eventSet,perr,native_code
      
      nevents=0
      eventSet=PAPI_NULL
      CALL PAPIF_create_eventset(eventSet,perr)
      IF(perr == PAPI_OK) TauStubLibData%PAPIEventSetHandle=eventSet
      IF(n > 0) THEN
        CALL GET_ENVIRONMENT_VARIABLE('TAU_METRICS',VALUE=TAU_METRICS)
        istp=INDEX(TAU_METRICS,';')
        istt=1
        DO WHILE(istp-istt > 0)
          papi_metric_name=TRIM(TAU_METRICS(istt:istp-1))
          !Check PAPI for the given event name and get the code
          CALL PAPIF_event_name_to_code(TRIM(papi_metric_name),native_code,perr)
          IF(perr == PAPI_OK) THEN
            !A valid name was provided add, the event to the PAPI event set
            CALL PAPIF_add_event(eventSet,native_code,perr)
            IF(perr == PAPI_OK) nevents=nevents+1
          ENDIF
          istt=istp+1
          istp=INDEX(TAU_METRICS(istt:n),';')+istt-1
        ENDDO
      
        !Process the last entry
        papi_metric_name=TAU_METRICS(istp+1:n)
        CALL PAPIF_event_name_to_code(TRIM(papi_metric_name),native_code,perr)
        IF(perr == PAPI_OK) THEN
          !A valid name was provided add, the event to the PAPI event set
          CALL PAPIF_add_event(eventSet,native_code,perr)
          IF(perr == PAPI_OK) nevents=nevents+1
        ENDIF
      ELSE
        !By default try to add the following preset PAPI events:
        !FP ops, L1 accesses, L1 misses, L2 accesses, L2 misses
        CALL PAPIF_add_event(eventSet,PAPI_FP_OPS,perr)
        IF(perr == PAPI_OK) nevents=nevents+1
        CALL PAPIF_add_event(eventSet,PAPI_L1_DCA,perr)
        IF(perr == PAPI_OK) nevents=nevents+1
        CALL PAPIF_add_event(eventSet,PAPI_L1_DCM,perr)
        IF(perr == PAPI_OK) nevents=nevents+1
        CALL PAPIF_add_event(eventSet,PAPI_L2_DCA,perr)
        IF(perr == PAPI_OK) nevents=nevents+1
        CALL PAPIF_add_event(eventSet,PAPI_L2_DCM,perr)
        IF(perr == PAPI_OK) nevents=nevents+1
      ENDIF
      TauStubLibData%nMetrics=nevents
      CALL PAPIF_start(eventSet,perr)
    ENDSUBROUTINE Init_PAPI_Event_Set
!
!-------------------------------------------------------------------------------
    FUNCTION GET_PAPI_VERSION() RESULT(pver)
      CHARACTER(LEN=7) :: pver
      WRITE(pver,'(4(i1,a1))') &
        IAND(ISHFT(PAPI_VER_CURRENT,-24),255),'.', & !Major Version
        IAND(ISHFT(PAPI_VER_CURRENT,-16),255),'.', & !Minor Version
        IAND(ISHFT(PAPI_VER_CURRENT,-8),255),'.', &  !Revision
        IAND(PAPI_VER_CURRENT,255)                   !Increment
    ENDFUNCTION 
!
!-------------------------------------------------------------------------------
    SUBROUTINE CreateProfDirs(dirnames,eventNames)
#ifdef __INTEL_COMPILER
      USE IFPORT !For SYSTEM function
#endif
#ifdef WIN32
      CHARACTER(LEN=*),PARAMETER :: mkdrCMD='mkdir '
#else
      CHARACTER(LEN=*),PARAMETER :: mkdrCMD='mkdir -p '
#endif
      CHARACTER(LEN=*),PARAMETER :: dirPrefix='MULTI__'
      TYPE(StringType),ALLOCATABLE,INTENT(INOUT) :: dirnames(:)
      TYPE(StringType),ALLOCATABLE,INTENT(INOUT) :: eventNames(:)
      CHARACTER(KIND=C_CHAR,LEN=PAPI_MAX_STR_LEN) :: papi_eventName
      INTEGER(SIK) :: i,ierr
      INTEGER(C_INT) :: nevents,perr
      INTEGER(C_INT),ALLOCATABLE :: eventCodes(:)
      
      IF(ALLOCATED(dirnames)) DEALLOCATE(dirnames)
      IF(ALLOCATED(eventnames)) DEALLOCATE(eventnames)
      ALLOCATE(dirnames(0:TauStubLibData%nMetrics))
      ALLOCATE(eventnames(0:TauStubLibData%nMetrics))
      dirnames(0)='.'
      IF(TauStubLibData%nMetrics > 0) THEN
        ALLOCATE(eventCodes(TauStubLibData%nMetrics))
        nevents=TauStubLibData%nMetrics
        CALL PAPIF_list_events(TauStubLibData%PAPIEventSetHandle,eventCodes,&
          nevents,perr)
        DO i=1,TauStubLibData%nMetrics
          CALL PAPIF_event_code_to_name(eventCodes(i),papi_eventName,perr)
          IF(perr == PAPI_OK) THEN
            eventnames(i)=TRIM(papi_eventName)
            dirnames(i)=dirPrefix//TRIM(papi_eventName)
!$OMP MASTER
            ierr=SYSTEM(mkdrCMD//CHAR(dirnames(i)))
!$OMP END MASTER
          ENDIF
        ENDDO
        dirnames(0)=dirPrefix//'LINUX_TIMERS'
!$OMP MASTER
        ierr=SYSTEM(mkdrCMD//CHAR(dirnames(0)))
!$OMP END MASTER
      ENDIF
      eventnames(0)='LINUX_TIMERS'
    ENDSUBROUTINE CreateProfDirs
#endif
!
!-------------------------------------------------------------------------------
!> @brief Attempts to estimate the overhead of the profiling calls.
!>
!> Not public. Should only be called by TAU_PROFILE_INIT
!>
    SUBROUTINE EstimateOverhead()
      INTEGER(SIK),PARAMETER,DIMENSION(2) :: pid=(/1,1/)  
      INTEGER(SIK) :: i
      INTEGER(C_INT) :: perr
      INTEGER(C_LONG_LONG) :: ptime_s,ptime_e,pmet(5,2)
      REAL(SDK) :: t
      TYPE(TimerType) :: ohead
      
      TauStubLibData%nProfiles(1)=1
      ALLOCATE(TauStubLibData%threadProfilesDB(1)%profiler)
      IF(TauStubLibData%nMetrics > 0) THEN
        ALLOCATE(TauStubLibData%threadProfilesDB(1)% &
          profiler%papiCounts(TauStubLibData%nMetrics))
        TauStubLibData%threadProfilesDB(1)% &
          profiler%papiCounts=0.0_SDK
        ALLOCATE(TauStubLibData%threadProfilesDB(1)% &
          profiler%tmpCounts(TauStubLibData%nMetrics,2))
        ALLOCATE(TauStubLibData%metricOverhead(TauStubLibData%nMetrics))
      ENDIF
      
      !Estimate the overhead by repeatedly making 10000 start/stop calls
      !Until a measureable amount of time has passed.
      t=0.0_SRK
      DO WHILE(t < 1.0_SDK)
#ifdef HAVE_PAPI
        CALL PAPIF_get_real_nsec(ptime_s)
        !CALL PAPIF_read(TauStubLibData%PAPIEventSetHandle,pmet(:,1),perr)
        DO i=1,10000
          CALL TAU_PROFILE_START(pid)
          CALL TAU_PROFILE_STOP(pid)
        ENDDO
        !CALL PAPIF_read(TauStubLibData%PAPIEventSetHandle,pmet(:,2),perr)
        CALL PAPIF_get_real_nsec(ptime_e)
        t=t+REAL(ptime_e-ptime_s)*1e-9_SDK
#else
        CALL ohead%tic()
        DO i=1,500000
          CALL TAU_PROFILE_START(pid)
          CALL TAU_PROFILE_STOP(pid)
        ENDDO
        CALL ohead%toc()
        t=t+ohead%getTimeReal()
#endif
      ENDDO
      TauStubLibData%tOverhead=1.e9_SDK* &
        TauStubLibData%threadProfilesDB(1)%profiler%timer%getTimeReal()/ &
          REAL(TauStubLibData%threadProfilesDB(1)%profiler%num_calls,SDK)
      !TauStubLibData%tOverhead=1.e6_SDK*t/ &
      !  REAL(TauStubLibData%threadProfilesDB(1)%profiler%num_calls,SDK)
      
      IF(TauStubLibData%nMetrics > 0) THEN
        TauStubLibData%metricOverhead= &
          TauStubLibData%threadProfilesDB(1)%profiler%papiCounts/ &
            REAL(TauStubLibData%threadProfilesDB(1)%profiler%num_calls,SDK)
      ENDIF
      TauStubLibData%nProfiles(1)=0
      DEALLOCATE(TauStubLibData%threadProfilesDB(1)%profiler)
    ENDSUBROUTINE EstimateOverhead
!
!-------------------------------------------------------------------------------
    FUNCTION getMemChar(memKb) RESULT(memstring)
      INTEGER(C_LONG_LONG) :: memKB
      CHARACTER(LEN=14) :: memstring
      CHARACTER(LEN=2) :: unit
      REAL(SRK) :: mem,Kbytes
      REAL(SRK),PARAMETER :: MB2KB=1024.0_SRK
      REAL(SRK),PARAMETER :: GB2KB=1048576_SRK
      
      
      Kbytes=REAL(memKb,SRK)
      mem=Kbytes
      unit='KB'
      IF(ABS(Kbytes) >= MB2KB .AND. ABS(Kbytes) < GB2KB) THEN
        mem=Kbytes/MB2KB
        unit='MB'
      ELSEIF(ABS(Kbytes) >= GB2KB) THEN
        mem=Kbytes/GB2KB
        unit='GB'
      ENDIF
      WRITE(memstring,'(f8.2,a)') mem,' '//unit
      memstring=ADJUSTR(memstring)
    ENDFUNCTION getMemChar
!
ENDMODULE TAU_Stubs
