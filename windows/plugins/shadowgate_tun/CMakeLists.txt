cmake_minimum_required(VERSION 3.14)
project(shadowgate_tun VERSION 0.1.0 LANGUAGES CXX)

set(PLUGIN_NAME "shadowgate_tun_plugin")

# Используем pkg-config для поиска Flutter
set(FLUTTER_MANUALLY_REGISTER_PLUGIN ON)

add_library(${PLUGIN_NAME} SHARED
  "src/shadowgate_tun_plugin.cpp"
)

# Включаем директории
target_include_directories(${PLUGIN_NAME} PRIVATE
  "include"
)

# Ссылаемся на Flutter
target_link_libraries(${PLUGIN_NAME} PRIVATE
  flutter_wrapper_plugin
)

# Windows-specific
target_compile_definitions(${PLUGIN_NAME} PRIVATE
  NOMINMAX
  WIN32_LEAN_AND_MEAN
)

# Копируем wintun.dll в выходную директорию
add_custom_command(TARGET ${PLUGIN_NAME} POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
  "${CMAKE_CURRENT_SOURCE_DIR}/bin/wintun.dll"
  "$<TARGET_FILE_DIR:${PLUGIN_NAME}>/wintun.dll"
  COMMENT "Copying wintun.dll to output directory"
)

set(PLUGIN_BUNDLED_LIBRARIES
  $<TARGET_FILE:${PLUGIN_NAME}>
  PARENT_SCOPE
)