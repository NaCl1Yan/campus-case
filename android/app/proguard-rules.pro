# kotlinx.serialization：保留 @Serializable 生成的 KSerializer
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.**
-keepclassmembers class **$$serializer { *; }
-keepclasseswithmembers class * {
    kotlinx.serialization.KSerializer serializer(...);
}
-keep,includedescriptorclasses class com.nacl1yan.campuscase.**$$serializer { *; }
-keep,includedescriptorclasses class com.nacl1yan.campuscase.**$Companion { *; }

# 领域模型（反序列化按字段名匹配，混淆后仍要保留字段）
-keep class com.nacl1yan.campuscase.domain.** { *; }
