package com.muhtadi.businessempire

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.LocalShipping
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.TrendingUp
import androidx.compose.material3.*
import androidx.compose.runtime.*
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

private data class CountryOption(val name: String, val currencyCode: String, val localeTag: String, val idrPerUnit: Double)
private val countryOptions = listOf(
    CountryOption("Indonesia", "IDR", "id-ID", 1.0),
    CountryOption("United States", "USD", "en-US", 16_000.0),
    CountryOption("United Kingdom", "GBP", "en-GB", 20_500.0),
    CountryOption("Germany", "EUR", "de-DE", 17_500.0),
    CountryOption("Japan", "JPY", "ja-JP", 105.0),
    CountryOption("Singapore", "SGD", "en-SG", 12_000.0)
)

private data class ContractOffer(
    val id: Int,
    val client: String,
    val cargo: String,
    val distanceKm: Int,
    val revenue: Long,
    val roadCost: Long,
    val term: PaymentTerm,
    val deadlineDays: Int,
    val requiredTruck: String
)

private data class GameInvoice(val client: String, val amount: Long, val dueDay: Int)

private val contractOffers = listOf(
    ContractOffer(1, "Nusantara Mart", "Barang ritel • 8 ton / 42 m³", 180, 18_000_000, 7_200_000, PaymentTerm.COD, 2, "Dry Box / Wingbox"),
    ContractOffer(2, "FreshFood Distribution", "Makanan beku • 5 ton / 28 m³", 260, 31_000_000, 13_500_000, PaymentTerm.NET_14, 3, "Reefer"),
    ContractOffer(3, "Karya Baja Industri", "Baja konstruksi • 18 ton / 20 m³", 95, 24_000_000, 9_500_000, PaymentTerm.NET_30, 2, "Flatbed / Trailer")
)

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { BusinessEmpireApp() }
    }
}

@Composable
fun BusinessEmpireApp() {
    val context = androidx.compose.ui.platform.LocalContext.current
    val prefs = remember { context.getSharedPreferences("business_empire_save", android.content.Context.MODE_PRIVATE) }
    var cash by remember { mutableLongStateOf(prefs.getLong("cash", 250_000_000L)) }
    var trucks by remember { mutableIntStateOf(prefs.getInt("trucks", 2)) }
    var truckCondition by remember { mutableIntStateOf(prefs.getInt("truck_condition", 100)) }
    var driverFatigue by remember { mutableFloatStateOf(prefs.getFloat("driver_fatigue", 0f)) }
    var deliveries by remember { mutableIntStateOf(prefs.getInt("deliveries", 0)) }
    var day by remember { mutableIntStateOf(prefs.getInt("day", 1)) }
    var speed by remember { mutableIntStateOf(prefs.getInt("speed", 1)) }
    var paused by remember { mutableStateOf(prefs.getBoolean("paused", false)) }
    var selectedCountryName by remember { mutableStateOf(prefs.getString("country", "Indonesia") ?: "Indonesia") }
    var selectedContractId by remember { mutableIntStateOf(prefs.getInt("selected_contract", 1)) }
    var useToll by remember { mutableStateOf(prefs.getBoolean("use_toll", true)) }
    var revenue by remember { mutableLongStateOf(prefs.getLong("revenue", 0L)) }
    var cogs by remember { mutableLongStateOf(prefs.getLong("cogs", 0L)) }
    var opex by remember { mutableLongStateOf(prefs.getLong("opex", 0L)) }
    var invoices by remember {
        mutableStateOf(
            prefs.getString("invoices", "")!!.split(";").filter { it.contains("|") }.mapNotNull {
                val p = it.split("|")
                if (p.size == 3) runCatching { GameInvoice(p[0], p[1].toLong(), p[2].toInt()) }.getOrNull() else null
            }
        )
    }
    var countryMenuExpanded by remember { mutableStateOf(false) }
    var log by remember {
        mutableStateOf(prefs.getString("log", null)?.split("~!~")?.filter { it.isNotBlank() }
            ?: listOf("Muhtadi Group resmi beroperasi. Pilih kontrak pertamamu."))
    }

    val selectedCountry = countryOptions.firstOrNull { it.name == selectedCountryName } ?: countryOptions.first()
    val formatter = remember(selectedCountry) {
        NumberFormat.getCurrencyInstance(Locale.forLanguageTag(selectedCountry.localeTag)).apply {
            currency = java.util.Currency.getInstance(selectedCountry.currencyCode)
            maximumFractionDigits = if (selectedCountry.currencyCode == "JPY") 0 else 0
        }
    }
    fun money(idr: Long): String = formatter.format(idr.toDouble() / selectedCountry.idrPerUnit)
    val receivables = invoices.sumOf { it.amount }
    val selectedContract = contractOffers.first { it.id == selectedContractId }
    val dailyOverhead = trucks * 180_000L + 250_000L
    val cashColor = if (cash < 20_000_000L) Color(0xFFFF7777) else Green

    fun addLog(message: String) { log = (listOf(message) + log).take(30) }
    fun saveGame() {
        prefs.edit()
            .putLong("cash", cash).putInt("trucks", trucks).putInt("truck_condition", truckCondition)
            .putFloat("driver_fatigue", driverFatigue).putInt("deliveries", deliveries)
            .putInt("day", day).putInt("speed", speed).putBoolean("paused", paused)
            .putString("country", selectedCountryName).putInt("selected_contract", selectedContractId)
            .putBoolean("use_toll", useToll).putLong("revenue", revenue).putLong("cogs", cogs)
            .putLong("opex", opex)
            .putString("invoices", invoices.joinToString(";") { "${it.client}|${it.amount}|${it.dueDay}" })
            .putString("log", log.joinToString("~!~")).apply()
    }
    LaunchedEffect(cash, trucks, truckCondition, driverFatigue, deliveries, day, speed, paused, selectedCountryName, selectedContractId, useToll, revenue, cogs, opex, invoices, log) {
        saveGame()
    }

    fun dispatchContract() {
        val routeExtra = if (useToll) selectedContract.distanceKm * 1_100L else 0L
        val actualCost = selectedContract.roadCost + routeExtra
        if (trucks <= 0) { addLog("Pengiriman gagal: armada tidak tersedia."); return }
        val driveHours = selectedContract.distanceKm.toDouble() / if (useToll) 65.0 else 35.0
        if (driverFatigue + driveHours > 9.0) { addLog("Dispatch ditolak: pengemudi melewati batas aman 9 jam. Istirahatkan pengemudi dengan melanjutkan hari."); return }
        if (truckCondition < 20) { addLog("Dispatch ditolak: kondisi truk kritis. Lakukan servis sebelum berangkat."); return }
        if (cash < actualCost) { addLog("Kas tidak cukup untuk membiayai pengiriman. Butuh ${money(actualCost)}."); return }
        cash -= actualCost
        cogs += actualCost
        revenue += selectedContract.revenue
        deliveries++
        driverFatigue = (driverFatigue + driveHours.toFloat()).coerceAtMost(9f)
        truckCondition = (truckCondition - (selectedContract.distanceKm / 100).coerceAtLeast(1)).coerceAtLeast(0)
        val due = day + selectedContract.term.days
        if (selectedContract.term == PaymentTerm.COD) {
            cash += selectedContract.revenue
            addLog("Kontrak ${selectedContract.client} selesai. COD diterima ${money(selectedContract.revenue)}. Biaya ${money(actualCost)}.")
        } else {
            invoices = invoices + GameInvoice(selectedContract.client, selectedContract.revenue, due)
            addLog("Invoice ${selectedContract.client} diterbitkan: ${money(selectedContract.revenue)}, jatuh tempo hari ke-$due.")
        }
    }

    MaterialTheme(colorScheme = darkColorScheme(primary = Green, background = Navy, surface = Panel, onSurface = Color.White)) {
        Scaffold(containerColor = Navy) { padding ->
            LazyColumn(
                modifier = Modifier.fillMaxSize().padding(padding),
                contentPadding = PaddingValues(18.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp)
            ) {
                item {
                    Text("BUSINESS EMPIRE • BY ADI", color = Green, fontSize = 12.sp, fontWeight = FontWeight.Bold, letterSpacing = 2.sp)
                    Text("CEO Control Center", color = Color.White, fontSize = 27.sp, fontWeight = FontWeight.Bold)
                    Text("Hari $day  •  ${if (paused) "PAUSED" else "SIMULASI ${speed}x"}", color = Muted)
                    Box {
                        OutlinedButton(onClick = { countryMenuExpanded = true }) { Text("🌐 ${selectedCountry.name} • ${selectedCountry.currencyCode}") }
                        DropdownMenu(expanded = countryMenuExpanded, onDismissRequest = { countryMenuExpanded = false }) {
                            countryOptions.forEach { option ->
                                DropdownMenuItem(text = { Text("${option.name} (${option.currencyCode})") }, onClick = {
                                    selectedCountryName = option.name; countryMenuExpanded = false
                                })
                            }
                        }
                    }
                }
                item {
                    Card(colors = CardDefaults.cardColors(containerColor = Panel), shape = RoundedCornerShape(18.dp)) {
                        Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                            Text("KAS TERSEDIA", color = Muted, fontSize = 11.sp)
                            Text(money(cash), color = cashColor, fontSize = 28.sp, fontWeight = FontWeight.Bold)
                            Text("Piutang belum cair: ${money(receivables)}", color = Color.White, fontSize = 13.sp)
                            if (cash < 20_000_000L) Text("PERINGATAN: Likuiditas menipis. Tunda ekspansi.", color = Color(0xFFFF7777), fontSize = 12.sp)
                        }
                    }
                }
                item {
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        StatCard("Armada", trucks.toString(), Icons.Default.LocalShipping, Modifier.weight(1f))
                        StatCard("Pengiriman", deliveries.toString(), Icons.Default.TrendingUp, Modifier.weight(1f))
                        StatCard("Invoice", invoices.size.toString(), Icons.Default.TrendingUp, Modifier.weight(1f))
                    }
                }
                item {
                    SectionTitle("MORNING BRIEFING")
                    Card(colors = CardDefaults.cardColors(containerColor = Panel)) {
                        Column(Modifier.padding(15.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            Text("Biaya kantor harian: ${money(dailyOverhead)}", color = Color.White)
                            Text("Tagihan jatuh tempo: ${invoices.filter { it.dueDay <= day }.size}", color = Muted)
                            Text("Omzet kumulatif: ${money(revenue)}", color = Muted)
                            Text("HPP kumulatif: ${money(cogs)}", color = Muted)
                            Text("Laba kotor: ${money(revenue - cogs)}", color = if (revenue >= cogs) Green else Color(0xFFFF7777), fontWeight = FontWeight.Bold)
                        }
                    }
                }
                item {
                    SectionTitle("TENDER & DISPATCH")
                    contractOffers.forEach { offer ->
                        Card(
                            colors = CardDefaults.cardColors(containerColor = if (selectedContractId == offer.id) Color(0xFF233D43) else Panel),
                            shape = RoundedCornerShape(14.dp),
                            onClick = { selectedContractId = offer.id }
                        ) {
                            Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Text(offer.client, color = Color.White, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                                    if (selectedContractId == offer.id) Text("DIPILIH", color = Green, fontSize = 10.sp)
                                }
                                Text(offer.cargo, color = Muted, fontSize = 12.sp)
                                Text("Rute ${offer.distanceKm} km • ${offer.requiredTruck}", color = Muted, fontSize = 12.sp)
                                Text("Nilai ${money(offer.revenue)} • Estimasi biaya ${money(offer.roadCost)} • ${offer.term.name}", color = Green, fontSize = 12.sp)
                            }
                        }
                    }
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text("Jalur tol (lebih cepat, lebih mahal)", color = Color.White, modifier = Modifier.weight(1f), fontSize = 12.sp)
                        Switch(checked = useToll, onCheckedChange = { useToll = it })
                    }
                    Text("Biaya rute dipotong dari kas saat dispatch. Pembayaran NET masuk sebagai piutang, bukan uang tunai.", color = Muted, fontSize = 11.sp)
                    Button(onClick = { dispatchContract() }, modifier = Modifier.fillMaxWidth(), colors = ButtonDefaults.buttonColors(containerColor = Green, contentColor = Navy)) {
                        Text("Kirim armada • ${selectedContract.client}", fontWeight = FontWeight.Bold)
                    }
                }
                item {
                    SectionTitle("KONTROL WAKTU & OPERASIONAL")
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                        IconButton(onClick = { paused = !paused }) {
                            Icon(if (paused) Icons.Default.PlayArrow else Icons.Default.Pause, contentDescription = "Pause", tint = Green)
                        }
                        listOf(1, 2, 5, 10).forEach { value ->
                            FilterChip(selected = speed == value, onClick = { speed = value; paused = false }, label = { Text("${value}x") })
                        }
                    }
                    Button(onClick = {
                        if (paused) { addLog("Simulasi dijeda. Tekan play untuk melanjutkan.") }
                        else {
                            repeat(speed) {
                                day++
                                driverFatigue = (driverFatigue - 6f).coerceAtLeast(0f)
                                val dueNow = invoices.filter { it.dueDay <= day }
                                if (dueNow.isNotEmpty()) {
                                    val collected = dueNow.sumOf { it.amount }
                                    cash += collected
                                    invoices = invoices - dueNow.toSet()
                                    addLog("Pembayaran invoice diterima: ${money(collected)}.")
                                }
                                if (cash >= dailyOverhead) {
                                    cash -= dailyOverhead; opex += dailyOverhead
                                } else {
                                    addLog("Kas tidak cukup membayar biaya kantor hari ke-$day!")
                                }
                            }
                            addLog("Hari maju ke $day. Biaya kantor harian ${money(dailyOverhead)}.")
                        }
                    }, modifier = Modifier.fillMaxWidth(), colors = ButtonDefaults.buttonColors(containerColor = Green, contentColor = Navy)) {
                        Text("Akhiri hari / Lanjutkan waktu", fontWeight = FontWeight.Bold)
                    }
                }
                item {
                    SectionTitle("KEUANGAN KORPORASI")
                    Card(colors = CardDefaults.cardColors(containerColor = Panel)) {
                        Column(Modifier.padding(15.dp), verticalArrangement = Arrangement.spacedBy(7.dp)) {
                            FinanceLine("Omzet", revenue, ::money)
                            FinanceLine("HPP / biaya jalan", -cogs, ::money)
                            FinanceLine("OPEX / kantor", -opex, ::money)
                            Divider(color = Muted.copy(alpha = .3f))
                            FinanceLine("Laba operasional sementara", revenue - cogs - opex, ::money, true)
                        }
                    }
                }
                item {
                    SectionTitle("KESELAMATAN & PERAWATAN ARMADA")
                    Card(colors = CardDefaults.cardColors(containerColor = Panel)) {
                        Column(Modifier.padding(15.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text("Kondisi kendaraan", color = Color.White, modifier = Modifier.weight(1f))
                                Text("$truckCondition%", color = if (truckCondition < 30) Color(0xFFFF7777) else Green, fontWeight = FontWeight.Bold)
                            }
                            LinearProgressIndicator(progress = { truckCondition / 100f }, modifier = Modifier.fillMaxWidth(), color = if (truckCondition < 30) Color(0xFFFF7777) else Green)
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text("Kelelahan pengemudi", color = Color.White, modifier = Modifier.weight(1f))
                                Text("${"%.1f".format(driverFatigue)}/9 jam", color = if (driverFatigue >= 7f) Color(0xFFFF7777) else Green, fontWeight = FontWeight.Bold)
                            }
                            LinearProgressIndicator(progress = { (driverFatigue / 9f).coerceIn(0f, 1f) }, modifier = Modifier.fillMaxWidth(), color = if (driverFatigue >= 7f) Color(0xFFFF7777) else Green)
                            Text("Setiap pengiriman menambah kelelahan dan keausan. Pengemudi pulih 6 jam per hari.", color = Muted, fontSize = 11.sp)
                            Button(onClick = {
                                val serviceCost = trucks * 2_500_000L
                                if (cash >= serviceCost) {
                                    cash -= serviceCost; opex += serviceCost; truckCondition = 100
                                    addLog("Servis preventif selesai. Biaya ${money(serviceCost)}; armada kembali 100%.")
                                } else addLog("Servis gagal: kas tidak cukup. Butuh ${money(serviceCost)}.")
                            }, modifier = Modifier.fillMaxWidth()) { Text("Servis seluruh armada • ${money(trucks * 2_500_000L)}") }
                        }
                    }
                }
                item {
                    SectionTitle("MANAJEMEN ARMADA")
                    Card(colors = CardDefaults.cardColors(containerColor = Panel)) {
                        Column(Modifier.padding(15.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Text("Truk operasional: $trucks", color = Color.White)
                            Text("Harga unit: ${money(75_000_000L)} • Beban kantor harian naik sesuai jumlah armada.", color = Muted, fontSize = 12.sp)
                            Button(onClick = {
                                if (cash >= 75_000_000L) { cash -= 75_000_000L; trucks++; addLog("Truk baru dibeli. Armada menjadi $trucks unit.") }
                                else addLog("Pembelian gagal: kas tidak cukup.")
                            }, modifier = Modifier.fillMaxWidth()) { Text("Beli truk • ${money(75_000_000L)}") }
                        }
                    }
                }
                item {
                    SectionTitle("AKTIVITAS TERBARU")
                    Card(colors = CardDefaults.cardColors(containerColor = Panel)) {
                        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            log.take(8).forEach { Text("• $it", color = Muted, fontSize = 12.sp) }
                        }
                    }
                }
                item { Text("PROTOTYPE 0.3.0 • Core business loop", color = Muted, fontSize = 10.sp) }
            }
        }
    }
}

@Composable
private fun FinanceLine(label: String, amount: Long, money: (Long) -> String, emphasize: Boolean = false) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(label, color = if (emphasize) Color.White else Muted, modifier = Modifier.weight(1f), fontSize = 12.sp)
        Text(money(amount), color = if (amount < 0) Color(0xFFFF8888) else if (emphasize) Green else Color.White, fontWeight = if (emphasize) FontWeight.Bold else FontWeight.Normal, fontSize = 12.sp)
    }
}

@Composable
private fun StatCard(title: String, value: String, icon: androidx.compose.ui.graphics.vector.ImageVector, modifier: Modifier = Modifier) {
    Card(modifier = modifier, colors = CardDefaults.cardColors(containerColor = Panel), shape = RoundedCornerShape(14.dp)) {
        Column(Modifier.padding(12.dp)) {
            Icon(icon, null, tint = Green)
            Spacer(Modifier.height(6.dp))
            Text(value, color = Color.White, fontSize = 20.sp, fontWeight = FontWeight.Bold)
            Text(title, color = Muted, fontSize = 11.sp)
        }
    }
}

@Composable
private fun SectionTitle(text: String) {
    Text(text, color = Green, fontSize = 12.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.1.sp)
}
