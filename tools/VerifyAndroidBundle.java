import com.android.aapt.Resources.XmlElement;
import com.android.aapt.Resources.XmlNode;
import com.android.bundle.Config.BundleConfig;
import java.util.zip.ZipFile;

/** Reads the actual AAB manifest/config using Android's generated protobuf APIs. */
class VerifyAndroidBundle {
    private static String attribute(XmlElement element, String name) {
        for (var value : element.getAttributeList()) {
            if (!value.getName().equals(name)) continue;
            if (!value.getValue().isEmpty()) return value.getValue();
            var primitive = value.getCompiledItem().getPrim();
            if (primitive.hasIntDecimalValue()) return Integer.toString(primitive.getIntDecimalValue());
            if (primitive.hasBooleanValue()) return Boolean.toString(primitive.getBooleanValue());
        }
        return "";
    }
    private static void require(boolean condition, String message) {
        if (!condition) throw new IllegalArgumentException(message);
    }
    public static void main(String[] args) throws Exception {
        try (var archive = new ZipFile(args[0])) {
            XmlElement manifest;
            try (var input = archive.getInputStream(archive.getEntry("base/manifest/AndroidManifest.xml"))) {
                manifest = XmlNode.parseFrom(input).getElement();
            }
            require(attribute(manifest, "package").equals("io.github.hik4.todorbit"), "Wrong AAB package");
            require(attribute(manifest, "versionName").equals(args[1]), "Wrong AAB version name");
            require(attribute(manifest, "versionCode").equals(args[2]), "Wrong AAB version code");
            boolean sdkChecked = false;
            for (var child : manifest.getChildList()) {
                var element = child.getElement();
                if (element.getName().equals("uses-sdk")) {
                    require(attribute(element, "minSdkVersion").equals("26"), "Wrong AAB minimum SDK");
                    sdkChecked = true;
                }
                if (element.getName().startsWith("uses-permission")) {
                    require(!attribute(element, "name").equals("android.permission.REQUEST_INSTALL_PACKAGES"), "Play AAB contains APK installation permission");
                }
                if (element.getName().equals("application")) {
                    require(!attribute(element, "debuggable").equals("true"), "Play AAB is debuggable");
                    for (var component : element.getChildList()) {
                        require(!attribute(component.getElement(), "name").endsWith("UpdateFileProvider"), "Play AAB contains the APK update provider");
                    }
                }
            }
            require(sdkChecked, "AAB minimum SDK missing");
            try (var input = archive.getInputStream(archive.getEntry("BundleConfig.pb"))) {
                var libraries = BundleConfig.parseFrom(input).getOptimizations().getUncompressNativeLibraries();
                require(libraries.getEnabled() && libraries.getAlignment().name().equals("PAGE_ALIGNMENT_16K"), "AAB must use uncompressed, 16 KiB aligned native libraries");
            }
            System.out.println("AAB identity, version, Play permission/provider separation and 16 KiB configuration verified.");
        }
    }
}
