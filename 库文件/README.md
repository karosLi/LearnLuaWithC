# libffi 编译


## 配置工程

```
sh autogen.sh
python generate-darwin-source-and-headers.py --only-ios 
```

## 修改工程

打开 libffi.xcodeproj

```
1、往 darwin_common/src 添加文件 java_raw_api.c 和 tramp.c 的引用

2、User-Defined->VALID_ARCHS 设置 arm64 armv7 armv7s x86_64 i386
```

## 构建

### 创建构建脚本

新建 build-ios.sh，放到与 libffi.xcodeproj 平级的目录，脚本内容如下:

```
#!/bin/sh
LIB_NAME=ffi
TARGET_NAME=libffi-iOS
PROJECT=libffi.xcodeproj

CONFIGURATION=Release
DEVICE=iphoneos
SIMULATOR=iphonesimulator
FAT=universal
OUTPUT=build
LIBRARY_NAME=lib${LIB_NAME}.a

xcodebuild -sdk ${DEVICE}  -configuration ${CONFIGURATION} -target ${TARGET_NAME} -project ${PROJECT} -verbose -arch arm64 -arch armv7s only_active_arch=no
xcodebuild -sdk ${SIMULATOR} -configuration ${CONFIGURATION} -target ${TARGET_NAME} -project ${PROJECT} -verbose -arch x86_64 -arch i386 only_active_arch=no

device_output=${OUTPUT}/${CONFIGURATION}-${DEVICE}
simulator_output=${OUTPUT}/${CONFIGURATION}-${SIMULATOR}
fatlib_output=${OUTPUT}/${CONFIGURATION}-${FAT}

rm -rf "${fatlib_output}"
mkdir -p "${fatlib_output}"
lipo -create -output "${fatlib_output}/${LIBRARY_NAME}" "${device_output}/${LIBRARY_NAME}" "${simulator_output}/${LIBRARY_NAME}"

out_header_dir="${fatlib_output}"
mkdir -p "${headers_dir}"
cp -r "darwin_common/include" "${out_header_dir}"
cp -r "darwin_ios/include" "${out_header_dir}"

open "${fatlib_output}"
```


### 运行脚本


```
chmod 777 ./build-ios.sh
./build-ios.sh
```

## 集成 ffi 到目标工程

### 修改头文件引用方式

```
1、把 include 和 libffi.a 加入 xcode 工程
2、搜索 #include <ffi 然后把所有 < 和 > 都替换成双引号
```

### 修改 build settings

