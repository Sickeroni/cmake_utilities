#[=======================================================================[.rst:
RepoMan
-------

Overview
^^^^^^^^
This module handles project dependencies.

Usage
^^^^^

Including the module is sufficient. It will automatically look for a dependencies file in ``PROJECT_SOURCE_DIR`` and resolve the dependencies recursively.

.. code-block:: cmake
  # Optional: use workspace instead of default FetchContent directories
  set(REPOMAN_DEPENDENCIES_USE_WORKSPACE ON CACHE BOOL "")

  # Optional: use a custom file name for dependency files
  set(REPOMAN_DEPENDENCIES_FILE_NAME "my_deps.txt" CACHE STRING "")

  include(RepoMan)

Alternatively, you can also include it via add_subdirectory() or provide it via FetchContent():

.. code-block:: cmake
  include(FetchContent)

  FetchContent_Declare(
    cmake_utilities
    GIT_REPOSITORY https://github.com/daixtrose/cmake_utilities
    GIT_TAG        main
  )

  # Optional: use workspace instead of default FetchContent directories
  set(REPOMAN_DEPENDENCIES_USE_WORKSPACE ON CACHE BOOL "")

  # Optional: use a custom file name for dependency files
  set(REPOMAN_DEPENDENCIES_FILE_NAME "my_deps.txt" CACHE STRING "")

  FetchContent_MakeAvailable(cmake_utilities)

You can also run the RepoManResolve.cmake script as a command directly from the command line. This also works for non-CMake projects. This s called ``script mode``, in contrast to ``project mode``, which is the normal usage of the module though a CMake project file.


In oder to actually do anything, the project root directory must contain a ``dependencies. txt`` file or a file with a different name, if ``REPOMAN_DEPENDENCIES_FILE_NAME`` is set accordingly.
This file must contain one line for each dependency, in the format given to ``FetchContent()``. All arguments of ``FetchContent()`` are supported. Empty and commented lines are also allowed and will be ignored.

Each dependency defined this way will be provided and included via ``add_subdirectory()``. Any sub-dependencies in a dependency's ``dependencies.txt`` will also be added. If a dependency has already been defined in a parent project, that definition takes precedence, so higher-level projects can override their child dependency's requirements.

Variables
^^^^^^^^^
The following variables modify the behaviour of the module. They are set to reasonable default values.

.. note::
  If you want to modify the variables in your project code, you should do so before including the module.

.. variable:: REPOMAN_DEPENDENCIES_USE_WORKSPACE
  Use the workspace defined by ``REPOMAN_DEPENDENCIES_WORKSPACE`` for dependency sources instead of the default FetchContent directories. This allows easier editing of dependency sources. Defaults to ``ON`` in script mode and ``OFF`` in project mode.


.. variable:: REPOMAN_DEPENDENCIES_FILE_NAME
  The dependencies file name, ``dependencies.txt`` by default.

#]=======================================================================]

if(CMAKE_SCRIPT_MODE_FILE)
    set(SCRIPT_MODE TRUE)
    # If RepoMan is run as a script (outside of a CMake project), the variables below do not have any meaning by default.
    set(PROJECT_SOURCE_DIR $ENV{PWD})
    set(FETCHCONTENT_BASE_DIR "${CMAKE_SOURCE_DIR}/../RepoMan-${PROJECT_DIRECTORY_NAME}-temp" CACHE PATH "The FetchContent base directory, modified by RepoMan." FORCE)
else()
    set(SCRIPT_MODE FALSE)
endif()

# Module Configuration
set(REPOMAN_DEPENDENCIES_USE_WORKSPACE ${SCRIPT_MODE} CACHE BOOL "Allow editing of dependencies. This puts the sources next to the main project to allow easier editing.")
set(REPOMAN_DEPENDENCIES_FILE_NAME "dependencies.txt" CACHE STRING "The dependencies file name.")
mark_as_advanced(REPOMAN_DEPENDENCIES_FILE_NAME)

include(FetchContent)

#[[
repoman__internal__handle_dependencies()

Resolve and provide dependencies recursively.

Arguments
^^^^^^^^^
DIRECTORY The directory to search for REPOMAN_DEPENDENCIES_FILE_NAME
#]]
function(repoman__internal__handle_dependencies DIRECTORY)
    set(REPOMAN_DEPENDENCY_FILE "${DIRECTORY}/${REPOMAN_DEPENDENCIES_FILE_NAME}")
    if(EXISTS "${REPOMAN_DEPENDENCY_FILE}")
        message(STATUS "Resolving dependencies of project ${DIRECTORY}")

        cmake_path(GET CMAKE_SOURCE_DIR FILENAME PROJECT_DIRECTORY_NAME)
        file(REAL_PATH "${CMAKE_SOURCE_DIR}/../${PROJECT_DIRECTORY_NAME}-dependencies" REPOMAN_WORKSPACE_INIT EXPAND_TILDE)
        set(REPOMAN_WORKSPACE "${REPOMAN_WORKSPACE_INIT}" CACHE STRING "The base workspace for projects.")
        if(NOT REPOMAN_WORKSPACE)
            message(WARNING "REPOMAN_WORKSPACE is empty, falling back to '${CMAKE_BINARY_DIR}'.")
            set(REPOMAN_WORKSPACE "${CMAKE_BINARY_DIR}" CACHE STRING "" FORCE)
        endif()
        file(MAKE_DIRECTORY "${REPOMAN_WORKSPACE}")

        if(NOT SCRIPT_MODE)
            set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${REPOMAN_DEPENDENCY_FILE}")
            set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${REPOMAN_WORKSPACE}")
        endif()

        unset(REPOMAN_DEPENDENCIES)
        file(STRINGS "${REPOMAN_DEPENDENCY_FILE}" REPOMAN_DEPENDENCY_SPECS ENCODING UTF-8)
        foreach(DEPENDENCY IN LISTS REPOMAN_DEPENDENCY_SPECS)
            # Filter out empty or commented lines
            if(DEPENDENCY MATCHES "^ *#.*" OR DEPENDENCY STREQUAL "")
                continue()
            endif()

            # Change line to list
            string(REPLACE " " ";" DEPENDENCY_INFO ${DEPENDENCY})

            # Parse dependency definition to be used in checks and printed information
            list(GET DEPENDENCY_INFO 0 REPOMAN_DEPENDENCY_NAME)

            unset(REPOMAN_DEPENDENCY_GIT_REPOSITORY)
            unset(REPOMAN_DEPENDENCY_URL)
            unset(REPOMAN_DEPENDENCY_SVN_REPOSITORY)
            unset(REPOMAN_DEPENDENCY_HG_REPOSITORY)
            unset(REPOMAN_DEPENDENCY_CVS_REPOSITORY)
            cmake_parse_arguments(REPOMAN_DEPENDENCY
                                  ""
                                  "GIT_REPOSITORY;GIT_TAG;URL_HASH;URL_MD5;SVN_REPOSITORY;SVN_REVISION;HG_REPOSITORY;HG_TAG;CVS_REPOSITORY;CVS_MODULE;CVS_TAG"
                                  "URL"
                                  "${DEPENDENCY_INFO}")
            if(REPOMAN_DEPENDENCY_GIT_REPOSITORY)
                set(REPOMAN_DEPENDENCY_URI ${REPOMAN_DEPENDENCY_GIT_REPOSITORY})
                set(REPOMAN_DEPENDENCY_REVISION  ${REPOMAN_DEPENDENCY_GIT_TAG})
            elseif(REPOMAN_DEPENDENCY_URL)
                set(REPOMAN_DEPENDENCY_URI ${REPOMAN_DEPENDENCY_URL})
                if(REPOMAN_DEPENDENCY_URL_HASH)
                    set(REPOMAN_DEPENDENCY_REVISION  ${REPOMAN_DEPENDENCY_URL_HASH})
                elseif(REPOMAN_DEPENDENCY_URL_MD5)
                    set(REPOMAN_DEPENDENCY_REVISION  ${REPOMAN_DEPENDENCY_URL_MD5})
                endif()
            elseif(REPOMAN_DEPENDENCY_SVN_REPOSITORY)
                set(REPOMAN_DEPENDENCY_URI ${REPOMAN_DEPENDENCY_SVN_REPOSITORY})
                set(REPOMAN_DEPENDENCY_REVISION  ${REPOMAN_DEPENDENCY_SVN_TAG})
            elseif(REPOMAN_DEPENDENCY_HG_REPOSITORY)
                set(REPOMAN_DEPENDENCY_URI ${REPOMAN_DEPENDENCY_HG_REPOSITORY})
                set(REPOMAN_DEPENDENCY_REVISION  ${REPOMAN_DEPENDENCY_HG_TAG})
            elseif(REPOMAN_DEPENDENCY_CVS_REPOSITORY)
                set(REPOMAN_DEPENDENCY_URI ${REPOMAN_DEPENDENCY_CVS_REPOSITORY})
                set(REPOMAN_DEPENDENCY_REVISION  ${REPOMAN_DEPENDENCY_CVS_TAG})
            endif()

            message(STATUS "Checking dependency '${REPOMAN_DEPENDENCY_NAME}': ${REPOMAN_DEPENDENCY_URI} @ ${REPOMAN_DEPENDENCY_REVISION}")

            # Set first-encountered revision
            get_property(OVERWRITE_REVISION GLOBAL PROPERTY ${REPOMAN_DEPENDENCY_NAME}_REVISION)
            if(NOT OVERWRITE_REVISION)
                set_property(GLOBAL PROPERTY ${REPOMAN_DEPENDENCY_NAME}_REVISION ${REPOMAN_DEPENDENCY_REVISION})
                set_property(GLOBAL APPEND PROPERTY GLOBAL_REPOMAN_DEPENDENCIES ${REPOMAN_DEPENDENCY_NAME})
            endif()
            set_property(GLOBAL APPEND PROPERTY ${REPOMAN_DEPENDENCY_NAME}_REQUESTED_REVISIONS ${REPOMAN_DEPENDENCY_REVISION})

            list(APPEND REPOMAN_DEPENDENCIES ${REPOMAN_DEPENDENCY_NAME})

            # Set depedencvy directories
            if(REPOMAN_DEPENDENCIES_USE_WORKSPACE)
                set(DEPENDENCY_SOURCE_DIR ${REPOMAN_WORKSPACE}/${REPOMAN_DEPENDENCY_NAME})
            else()
                set(DEPENDENCY_SOURCE_DIR ${FETCHCONTENT_BASE_DIR}/${REPOMAN_DEPENDENCY_NAME}-src)
            endif()
            set(DEPENDENCY_BINARY_DIR ${FETCHCONTENT_BASE_DIR}/${REPOMAN_DEPENDENCY_NAME}-build)
            set(DEPENDENCY_SUBBUILD_DIR ${FETCHCONTENT_BASE_DIR}/${REPOMAN_DEPENDENCY_NAME}-subbuild)

            # FetchContent_Declare() defines properties and i thus not usable in script mode
            if(NOT SCRIPT_MODE)
                FetchContent_Declare(${DEPENDENCY_INFO}
                                     SOURCE_DIR "${DEPENDENCY_SOURCE_DIR}"
                                     BINARY_DIR "${DEPENDENCY_BINARY_DIR}"
                                     SUBBUILD_DIR "${DEPENDENCY_SUBBUILD_DIR}")
            endif()

            # Handle dependency
            if(NOT EXISTS "${DEPENDENCY_SOURCE_DIR}" OR NOT REPOMAN_DEPENDENCIES_USE_WORKSPACE)
                # Define and fetch dependencies
                FetchContent_GetProperties(${REPOMAN_DEPENDENCY_NAME} POPULATED IS_POPULATED)
                if(NOT IS_POPULATED)
                    message(STATUS "Initializing in '${DEPENDENCY_SOURCE_DIR}'")

                    if(SCRIPT_MODE)
                        # Script mode without FetchContent_Declare(): define and provide
                        FetchContent_Populate(${DEPENDENCY_INFO}
                                              SOURCE_DIR "${DEPENDENCY_SOURCE_DIR}"
                                              BINARY_DIR "${DEPENDENCY_BINARY_DIR}"
                                              SUBBUILD_DIR "${DEPENDENCY_SUBBUILD_DIR}")
                    else()
                        # Inside a CMake project: dependency has been declared with FetchContent_Declare() above.
                        FetchContent_Populate(${REPOMAN_DEPENDENCY_NAME})
                    endif()

                    if(NOT REPOMAN_DEPENDENCY_URI)
                        string(TOLOWER ${REPOMAN_DEPENDENCY_NAME} LOWER_NAME)
                        string(TOUPPER ${REPOMAN_DEPENDENCY_NAME} UPPER_NAME)
                        set(FETCHCONTENT_SOURCE_DIR_${UPPER_NAME} "${${LOWER_NAME}_SOURCE_DIR}")
                    endif()
                endif()
            else()
                # Dependency already exists, show status information
                string(TOLOWER ${REPOMAN_DEPENDENCY_NAME} LOWER_NAME)
                set(${LOWER_NAME}_SOURCE_DIR "${DEPENDENCY_SOURCE_DIR}")
                set(${LOWER_NAME}_BINARY_DIR "${DEPENDENCY_BINARY_DIR}")
                set(${LOWER_NAME}_POPULATED TRUE)
                file(MAKE_DIRECTORY "${DEPENDENCY_BINARY_DIR}")

                if(OVERWRITE_REVISION AND NOT REPOMAN_DEPENDENCY_REVISION STREQUAL OVERWRITE_REVISION)
                    # Print message in case a dependency is overridden by a parent.
                    message(STATUS "Dependency '${REPOMAN_DEPENDENCY_NAME} @ ${REPOMAN_DEPENDENCY_REVISION}' is overridden with '${REPOMAN_DEPENDENCY_NAME} @ ${OVERWRITE_REVISION}'")
                    set(REPOMAN_DEPENDENCY_REVISION ${OVERWRITE_REVISION})
                endif()

                if (EXISTS ${DEPENDENCY_SOURCE_DIR}/.git AND NOT OVERWRITE_REVISION)
                    # Show status of local repository
                    # Only supports git for now
                    set(NAME ${REPOMAN_DEPENDENCY_NAME})
                    set(REPO ${DEPENDENCY_SOURCE_DIR})
                    set(EXPECTED_REVISION ${REPOMAN_DEPENDENCY_REVISION})
                    set(EXPECTED_REMOTE ${REPOMAN_DEPENDENCY_URI})
                    include(${CMAKE_CURRENT_FUNCTION_LIST_DIR}/RepoManStatus.cmake)
                endif()
            endif()
        endforeach()

        # Include dependencies as sub-projects and resolve their dependencies
        foreach(DEPENDENCY IN LISTS REPOMAN_DEPENDENCIES)
            get_property(ADDED GLOBAL PROPERTY ${DEPENDENCY}_ADDED)
            string(TOLOWER ${DEPENDENCY} NAME)

            # Add not-yet included dependencies
            if(NOT ADDED AND ${NAME}_POPULATED)
                if(SCRIPT_MODE)
                    # add_subdirectory() does not work in script mode, just call the setup function recursively
                    repoman__internal__handle_dependencies(${${NAME}_SOURCE_DIR})
                else()
                    add_subdirectory(${${NAME}_SOURCE_DIR} ${${NAME}_BINARY_DIR})
                endif()
                set_property(GLOBAL PROPERTY ${DEPENDENCY}_ADDED TRUE)
            endif()
        endforeach()
    endif()
endfunction()

# repoman__internal__print_summary()
# Prints a summary of requested and provided dependencies.
function(repoman__internal__print_summary)
    get_property(REPOMAN_DEPENDENCIES GLOBAL PROPERTY GLOBAL_REPOMAN_DEPENDENCIES)
    if(REPOMAN_DEPENDENCIES)
        message(STATUS "Dependencies:")
        foreach(DEPENDENCY IN LISTS REPOMAN_DEPENDENCIES)
            get_property(REVISION GLOBAL PROPERTY ${DEPENDENCY}_REVISION)
            get_property(ALL_REVISIONS GLOBAL PROPERTY ${DEPENDENCY}_REQUESTED_REVISIONS)
            string(REPLACE ";" ", " ALL_REVISIONS "${ALL_REVISIONS}")
            message(STATUS "    ${DEPENDENCY} @ ${REVISION}, chosen from [${ALL_REVISIONS}]")
        endforeach()
    endif()
endfunction()

# Run dependency resolution
repoman__internal__handle_dependencies(${PROJECT_SOURCE_DIR})

# Print summary after resolving all dependencies.
if(SCRIPT_MODE)
    repoman__internal__print_summary()
    file(REMOVE_RECURSE "${FETCHCONTENT_BASE_DIR}")
else()
    get_property(DEFER_INSTALLED GLOBAL PROPERTY REPOMAN_DEFER_INSTALLED)
    if(NOT DEFER_INSTALLED)
        cmake_language(DEFER DIRECTORY "${CMAKE_SOURCE_DIR}" ID repo_man_summary CALL repoman__internal__print_summary)
        set_property(GLOBAL PROPERTY REPOMAN_DEFER_INSTALLED TRUE)
    endif()
endif()

# Prevent setup function to be called from outside after inclusion
function(repoman__internal__handle_dependencies)
    message(FATAL_ERROR "Please do not call any RepoMan functions. Including the module is sufficient.")
endfunction()
