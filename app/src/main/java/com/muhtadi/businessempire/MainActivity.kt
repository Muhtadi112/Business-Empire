package com.muhtadi.businessempire

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.LocalShipping
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.TrendingUp
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.text.NumberFormat
import java.util.Locale

private val Navy = Color(0xFF101827)
private val Panel = Color(0xFF1B283B)
private val Green = Color(0xFF31D69A)
private val Muted = Color(0xFF9AA9BD)

private data class CountryOption(
    val name: String,
    val currencyCode: String,
    val localeTag: String,
    val idrPerUnit: Double
)

private val countryOptions = listOf(
    CountryOption("Indonesia", "IDR", "id-ID", 1.0),
    CountryOption("United States", "USD", "en-US", 16_000.0),
    CountryOption("United Kingdom", "GBP", "en-GB", 20_500.0),
    CountryOption("Germany", "EUR", "de-DE", 17_500.0),
    CountryOption("Japan", "JPY", "ja-JP", 105.0),
    CountryOption("Singapore", "SGD", "en-SG", 12_000.0)
)

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { BusinessEmpireApp() }
    }
}

@Composable
fun BusinessEmpireApp() {
    val context = LocalContext.current
    val prefs = remember { context.getSharedPreferences("business_empire_save", android.content.Context.MODE_PRIVATE) }
    var cash by remember { mutableLongStateOf(prefs.getLong("cash", 250_000_000L)) }
    var trucks by remember { mutableIntStateOf(prefs.getInt("trucks", 2)) }
    var deliveries by remember { mutableIntStateOf(prefs.getInt("deliveries", 0)) }
    var day by remember { mutableIntStateOf(prefs.getInt("day", 1)) }
    var speed by remember { mutableIntStateOf(prefs.getInt("speed", 1)) }
    var paused by remember { mutableStateOf(prefs.getBoolean("paused", false)) }
    var selectedCountryName by remember { mutableStateOf(prefs.getString("country", "Indonesia") ?: "Indonesia") }
    var countryMenuExpanded by remember { mutableStateOf(false) }
    val selectedCountry = countryOptions.firstOrNull { it.name == selectedCountryName } ?: countryOptions.first()
    val currency = remember(selectedCountry) {
        NumberFormat.getCurrencyInstance(Locale.forLanguageTag(selectedCountry.localeTag)).apply {
            currency = java.util.Currency.getInstance(selectedCountry.currencyCode)
            maximumFractionDigits = if (selectedCountry.currencyCode == "JPY") 0 else 2
        }
    }
    fun money(amountInIdr: Long): String =
        currency.format(amountInIdr.toDouble() / selectedCountry.idrPerUnit)
    var log by remember {
        mutableStateOf(
            prefs.getString("log", null)
                ?.split("\\n")
                ?.filter { it.isNotBlank() }
                ?: listOf("Perusahaan didirikan. Selamat datang, CEO!")
        )
    }

    // Simpan otomatis setiap data permainan berubah.
    LaunchedEffect(cash, trucks, deliveries, day, speed, paused, log) {
        prefs.edit()
            .putLong("cash", cash)
            .putInt("trucks", trucks)
            .putInt("deliveries", deliveries)
            .putInt("day", day)
            .putInt("speed", speed)
            .putBoolean("paused", paused)
            .putString("country", selectedCountryName)
            .putString("log", log.take(30).joinToString("\\n"))
            .apply()
    }
    MaterialTheme(colorScheme = darkColorScheme(primary = Green, background = Navy, surface = Panel, onSurface = Color.White)) {
        Scaffold(containerColor = Navy) { padding ->
            LazyColumn(
                modifier = Modifier.fillMaxSize().padding(padding),
                contentPadding = PaddingValues(20.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                item {
                    Text("BUSINESS EMPIRE", color = Green, fontSize = 13.sp, fontWeight = FontWeight.Bold, letterSpacing = 2.sp)
                    Text("Dashboard CEO", color = Color.White, fontSize = 28.sp, fontWeight = FontWeight.Bold)
                    Text("Hari $day • ${if (paused) "Dijeda" else "Berjalan ${speed}x"}", color = Muted)
                    Spacer(Modifier.height(8.dp))
                    Box {
                        OutlinedButton(onClick = { countryMenuExpanded = true }) {
                            Text("🌐 ${selectedCountry.name} • ${selectedCountry.currencyCode}")
                        }
                        DropdownMenu(expanded = countryMenuExpanded, onDismissRequest = { countryMenuExpanded = false }) {
                            countryOptions.forEach { option ->
                                DropdownMenuItem(
                                    text = { Text("${option.name} (${option.currencyCode})") },
                                    onClick = {
                                        selectedCountryName = option.name
                                        countryMenuExpanded = false
                                        log = listOf("Basis negara diubah ke ${option.name}.") + log
                                    }
                                )
                            }
                        }
                    }
                }
                item {
                    Card(colors = CardDefaults.cardColors(containerColor = Panel), shape = RoundedCornerShape(20.dp)) {
                        Column(Modifier.padding(20.dp)) {
                            Text("KAS PERUSAHAAN", color = Muted, fontSize = 12.sp)
                            Text(money(cash), color = Green, fontSize = 27.sp, fontWeight = FontWeight.Bold)
                            Text("Muhtadi Group", color = Color.White, fontSize = 15.sp)
                        }
                    }
                }
                item {
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        StatCard("Armada truk", trucks.toString(), Icons.Default.LocalShipping, Modifier.weight(1f))
                        StatCard("Pengiriman", deliveries.toString(), Icons.Default.TrendingUp, Modifier.weight(1f))
                    }
                }
                item {
                    SectionTitle("KONTROL WAKTU")
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                        IconButton(onClick = { paused = !paused }) {
                            Icon(if (paused) Icons.Default.PlayArrow else Icons.Default.Pause, contentDescription = "Pause", tint = Green)
                        }
                        listOf(1, 2, 5, 10).forEach { value ->
                            FilterChip(selected = speed == value, onClick = { speed = value; paused = false }, label = { Text("${value}x") })
                        }
                    }
                    Button(onClick = {
                        if (!paused) {
                            day += speed
                            val income = trucks * 1_500_000L * speed
                            val cost = trucks * 450_000L * speed
                            cash += income - cost
                            deliveries += trucks * speed
                            log = listOf("Hari $day: ${trucks * speed} pengiriman. Laba ${money(income - cost)}.") + log
                        }
                    }, modifier = Modifier.fillMaxWidth(), colors = ButtonDefaults.buttonColors(containerColor = Green, contentColor = Navy)) {
                        Text("Jalankan simulasi", fontWeight = FontWeight.Bold)
                    }
                }
                item {
                    SectionTitle("MANAJEMEN LOGISTIK")
                    Card(colors = CardDefaults.cardColors(containerColor = Panel)) {
                        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(Icons.Default.LocalShipping, null, tint = Green)
                                Spacer(Modifier.width(8.dp))
                                Text("Beli truk baru", color = Color.White, fontWeight = FontWeight.SemiBold)
                            }
                            Text("Harga unit: ${money(75_000_000L)}", color = Muted)
                            Button(onClick = {
                                if (cash >= 75_000_000L) {
                                    cash -= 75_000_000L
                                    trucks++
                                    log = listOf("Truk baru dibeli. Total armada: $trucks.") + log
                                } else log = listOf("Dana tidak cukup untuk membeli truk.") + log
                            }, modifier = Modifier.fillMaxWidth()) { Text("Beli truk — Rp75 juta") }
                        }
                    }
                }
                item {
                    SectionTitle("AKTIVITAS TERBARU")
                    Card(colors = CardDefaults.cardColors(containerColor = Panel)) {
                        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                            log.take(6).forEach { Text("• $it", color = Muted, fontSize = 13.sp) }
                        }
                    }
                }
                item { Text("BUSINESS EMPIRE • Prototype 0.2.0", color = Muted, fontSize = 11.sp) }
            }
        }
    }
}

@Composable
private fun StatCard(title: String, value: String, icon: androidx.compose.ui.graphics.vector.ImageVector, modifier: Modifier = Modifier) {
    Card(modifier = modifier, colors = CardDefaults.cardColors(containerColor = Panel), shape = RoundedCornerShape(16.dp)) {
        Column(Modifier.padding(16.dp)) {
            Icon(icon, null, tint = Green)
            Spacer(Modifier.height(8.dp))
            Text(value, color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.Bold)
            Text(title, color = Muted, fontSize = 12.sp)
        }
    }
}

@Composable
private fun SectionTitle(text: String) {
    Text(text, color = Green, fontSize = 12.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.2.sp)
}
