package ba.balkansmartlife.app

import android.content.Context
import android.content.res.Configuration
import android.os.LocaleList
import io.flutter.embedding.android.FlutterActivity
import java.util.Locale

class MainActivity : FlutterActivity() {
    override fun attachBaseContext(newBase: Context) {
        val locale = preferredBhsLocale(newBase)
        Locale.setDefault(locale)

        val configuration = Configuration(newBase.resources.configuration).apply {
            setLocale(locale)
            setLocales(LocaleList(locale))
            setLayoutDirection(locale)
        }

        super.attachBaseContext(newBase.createConfigurationContext(configuration))
    }

    private fun preferredBhsLocale(context: Context): Locale {
        val deviceLocale = context.resources.configuration.locales[0]

        return when (deviceLocale.language) {
            "bs", "hr", "sr" -> deviceLocale
            else -> Locale.forLanguageTag("bs-BA")
        }
    }
}
