cmake_minimum_required(VERSION 3.18)

project(MNRakSAMPCore LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)


set(RAKNET_SOURCES 
	raknet/src/BitStream.cpp
	raknet/src/CheckSum.cpp
	raknet/src/DataBlockEncryptor.cpp
	raknet/src/DS_HuffmanEncodingTree.cpp
	raknet/src/GetTime.cpp
	raknet/src/InternalPacketPool.cpp
	raknet/src/NetworkIDGenerator.cpp
	raknet/src/NetworkTypes.cpp
	raknet/src/PluginInterface.cpp
	raknet/src/RakClient.cpp
	raknet/src/RakNetworkFactory.cpp
	raknet/src/RakPeer.cpp
	raknet/src/RakServer.cpp
	raknet/src/RakSleep.cpp
	raknet/src/Rand.cpp
	raknet/src/ReliabilityLayer.cpp
	raknet/src/rijndael.cpp
	raknet/src/RPCMap.cpp
	raknet/src/SAMPAuth.cpp
	raknet/src/SAMPNetEncr.cpp
	raknet/src/SAMPRPC.cpp
	raknet/src/SHA1.cpp
	raknet/src/SimpleMutex.cpp
	raknet/src/SocketLayer.cpp
	raknet/src/StringCompressor.cpp
	raknet/src/StringTable.cpp
)



set(CORE_SOURCES
    main.cpp
    misc_funcs.cpp
    netgame.cpp
    netrpc.cpp 
)


add_library(MNRakSAMPCore SHARED
    ${RAKNET_SOURCES}
    ${CORE_SOURCES}
)

target_compile_definitions(MNRakSAMPCore PRIVATE
    RAKSAMP_CLIENT
    _RAKNET_THREADSAFE
)
target_include_directories(MNRakSAMPCore PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/raknet/include
    ${CMAKE_CURRENT_SOURCE_DIR}
)



if(WIN32)
    target_compile_definitions(MNRakSAMPCore PRIVATE
        _CRT_SECURE_NO_WARNINGS
        _WINSOCK_DEPRECATED_NO_WARNINGS
        WIN32_LEAN_AND_MEAN
        NOMINMAX
    )
    target_link_libraries(MNRakSAMPCore PRIVATE ws2_32)
    set_target_properties(MNRakSAMPCore PROPERTIES PREFIX "")
    
elseif(ANDROID)
    target_compile_definitions(MNRakSAMPCore PRIVATE ANDROID __ANDROID__)
    find_library(LOG_LIB log)
    if(LOG_LIB)
        target_link_libraries(MNRakSAMPCore PRIVATE ${LOG_LIB})
    endif()
    set_target_properties(MNRakSAMPCore PROPERTIES
        CXX_VISIBILITY_PRESET hidden
        VISIBILITY_INLINES_HIDDEN ON
    )
    
elseif(APPLE)
    target_compile_definitions(MNRakSAMPCore PRIVATE __APPLE__)
    set_target_properties(MNRakSAMPCore PROPERTIES
        CXX_VISIBILITY_PRESET hidden
        VISIBILITY_INLINES_HIDDEN ON
    )
    
elseif(UNIX)
    target_compile_definitions(MNRakSAMPCore PRIVATE _POSIX_C_SOURCE=200809L)
    find_package(Threads REQUIRED)
    target_link_libraries(MNRakSAMPCore PRIVATE Threads::Threads)
    set_target_properties(MNRakSAMPCore PROPERTIES
        CXX_VISIBILITY_PRESET hidden
        VISIBILITY_INLINES_HIDDEN ON
    )
endif()

if(MSVC)
    target_compile_options(MNRakSAMPCore PRIVATE /W3 /WX-)
else()
    target_compile_options(MNRakSAMPCore PRIVATE
        -Wall -Wextra -Wno-unused-parameter -Wno-missing-field-initializers
    )
endif()

