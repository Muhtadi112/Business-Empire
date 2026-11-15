package com.muhtadi.businessempire

import kotlin.math.max
import kotlin.math.min

/**
 * Pure game-domain model. All money is stored in IDR minor units (whole rupiah);
 * UI currency selection is presentation-only and must never change these values.
 */
enum class PaymentTerm(val days: Int) {
    COD(0), NET_14(14), NET_30(30), NET_60(60)
}

enum class CargoType(
    val label: String,
    val kgPerCubicMeter: Double,
    val requiredBody: TruckBody,
    val requiresCertification: Boolean = false
) {
    RETAIL("Ritel umum", 180.0, TruckBody.DRY_BOX),
    FROZEN_FOOD("Makanan beku", 350.0, TruckBody.REEFER),
    PHARMACEUTICAL("Farmasi", 220.0, TruckBody.REEFER),
    CONTAINER("Kontainer", 1_200.0, TruckBody.FLATBED),
    HEAVY_EQUIPMENT("Alat berat", 900.0, TruckBody.TRAILER),
    HAZMAT("Bahan berbahaya (B3)", 700.0, TruckBody.HAZMAT, true)
}

enum class TruckBody { DRY_BOX, WINGBOX, REEFER, FLATBED, TRAILER, HAZMAT }

data class TruckSpec(
    val body: TruckBody,
    val maxPayloadKg: Int,
    val cargoVolumeM3: Double,
    val fuelLitersPerKm: Double,
    val purchasePriceIdr: Long,
    val dailyDepreciationIdr: Long,
    val certifiedForHazmat: Boolean = false
)

data class CargoLoad(val type: CargoType, val weightKg: Int, val volumeM3: Double) {
    init {
        require(weightKg > 0) { "Berat muatan harus lebih dari nol." }
        require(volumeM3 > 0.0) { "Volume muatan harus lebih dari nol." }
    }
}

data class CapacityCheck(
    val accepted: Boolean,
    val weightUtilization: Double,
    val volumeUtilization: Double,
    val reason: String? = null
)

fun checkCapacity(truck: TruckSpec, load: CargoLoad): CapacityCheck {
    val weightUse = load.weightKg.toDouble() / truck.maxPayloadKg
    val volumeUse = load.volumeM3 / truck.cargoVolumeM3
    val bodyMatches = when (load.type.requiredBody) {
        TruckBody.DRY_BOX -> truck.body == TruckBody.DRY_BOX || truck.body == TruckBody.WINGBOX
        else -> truck.body == load.type.requiredBody
    }
    val certified = !load.type.requiresCertification || truck.certifiedForHazmat
    val reason = when {
        !bodyMatches -> "Tipe karoseri tidak sesuai dengan kargo."
        !certified -> "Kargo B3 membutuhkan sertifikasi khusus."
        weightUse > 1.0 -> "Muatan melebihi batas tonase."
        volumeUse > 1.0 -> "Muatan melebihi kapasitas volume."
        else -> null
    }
    return CapacityCheck(reason == null, weightUse, volumeUse, reason)
}

data class DeliveryCost(
    val fuelIdr: Long,
    val tollIdr: Long,
    val driverAllowanceIdr: Long,
    val maintenanceReserveIdr: Long,
    val reeferExtraFuelIdr: Long = 0L
) {
    val totalIdr: Long
        get() = fuelIdr + tollIdr + driverAllowanceIdr + maintenanceReserveIdr + reeferExtraFuelIdr
}

data class Contract(
    val id: Long,
    val clientName: String,
    val revenueIdr: Long,
    val distanceKm: Int,
    val paymentTerm: PaymentTerm,
    val deadlineDay: Int,
    val deliveryCost: DeliveryCost
)

data class Invoice(
    val id: Long,
    val contractId: Long,
    val clientName: String,
    val amountIdr: Long,
    val issuedDay: Int,
    val dueDay: Int,
    val paid: Boolean = false
) {
    fun isOverdue(currentDay: Int): Boolean = !paid && currentDay > dueDay
}

data class Loan(
    val principalIdr: Long,
    val annualInterestRate: Double,
    val remainingDays: Int,
    val dailyInstallmentIdr: Long,
    val missedPayments: Int = 0
)

data class FinancialSnapshot(
    val cashIdr: Long,
    val accountsReceivableIdr: Long,
    val revenueIdr: Long,
    val cogsIdr: Long,
    val opexIdr: Long,
    val depreciationIdr: Long,
    val interestIdr: Long,
    val taxIdr: Long
) {
    val grossProfitIdr: Long get() = revenueIdr - cogsIdr
    val operatingProfitIdr: Long get() = grossProfitIdr - opexIdr - depreciationIdr
    val netProfitIdr: Long get() = operatingProfitIdr - interestIdr - taxIdr
}

/**
 * Small deterministic finance ledger for the first playable vertical slice.
 * Contract revenue is recognized when delivery completes; cash is collected
 * only when the invoice due date is reached. Direct delivery costs are paid now.
 */
class FinanceLedger(
    openingCashIdr: Long = 250_000_000L,
    private val corporateTaxRate: Double = 0.22
) {
    var cashIdr: Long = openingCashIdr
        private set
    private val invoices = mutableListOf<Invoice>()
    private var nextInvoiceId = 1L

    var revenueIdr: Long = 0L
        private set
    var cogsIdr: Long = 0L
        private set
    var opexIdr: Long = 0L
        private set
    var depreciationIdr: Long = 0L
        private set
    var interestIdr: Long = 0L
        private set
    var taxIdr: Long = 0L
        private set

    val accountsReceivableIdr: Long
        get() = invoices.filterNot { it.paid }.sumOf { it.amountIdr }

    val outstandingInvoices: List<Invoice>
        get() = invoices.filterNot { it.paid }.toList()

    fun completeDelivery(contract: Contract, currentDay: Int): Invoice? {
        require(contract.revenueIdr > 0L)
        val cost = contract.deliveryCost.totalIdr
        if (cashIdr < cost) return null
        cashIdr -= cost
        cogsIdr += cost
        revenueIdr += contract.revenueIdr
        val invoice = Invoice(
            id = nextInvoiceId++,
            contractId = contract.id,
            clientName = contract.clientName,
            amountIdr = contract.revenueIdr,
            issuedDay = currentDay,
            dueDay = currentDay + contract.paymentTerm.days
        )
        if (contract.paymentTerm == PaymentTerm.COD) {
            cashIdr += invoice.amountIdr
            invoices += invoice.copy(paid = true)
        } else {
            invoices += invoice
        }
        return invoice
    }

    fun collectDueInvoices(currentDay: Int): Long {
        var collected = 0L
        invoices.indices.forEach { index ->
            val invoice = invoices[index]
            if (!invoice.paid && currentDay >= invoice.dueDay) {
                collected += invoice.amountIdr
                invoices[index] = invoice.copy(paid = true)
            }
        }
        cashIdr += collected
        return collected
    }

    fun payOpex(amountIdr: Long): Boolean {
        require(amountIdr >= 0L)
        if (cashIdr < amountIdr) return false
        cashIdr -= amountIdr
        opexIdr += amountIdr
        return true
    }

    fun recordDepreciation(amountIdr: Long) {
        depreciationIdr += max(0L, amountIdr)
    }

    fun payLoanInterest(amountIdr: Long): Boolean {
        require(amountIdr >= 0L)
        if (cashIdr < amountIdr) return false
        cashIdr -= amountIdr
        interestIdr += amountIdr
        return true
    }

    /** Tax is assessed on positive pre-tax profit; it is paid immediately. */
    fun settleCorporateTax(): Long {
        val taxableProfit = revenueIdr - cogsIdr - opexIdr - depreciationIdr - interestIdr - taxIdr
        val tax = (max(0L, taxableProfit) * corporateTaxRate).toLong()
        val payable = min(tax, cashIdr)
        cashIdr -= payable
        taxIdr += payable
        return payable
    }

    fun snapshot() = FinancialSnapshot(
        cashIdr, accountsReceivableIdr, revenueIdr, cogsIdr,
        opexIdr, depreciationIdr, interestIdr, taxIdr
    )
}

data class Driver(
    val name: String,
    val skill: Int,
    val loyalty: Int,
    val stress: Int,
    val fatigueHours: Double,
    val dailyDrivingLimitHours: Double = 9.0
) {
    fun canDrive(hours: Double): Boolean =
        hours > 0.0 && fatigueHours + hours <= dailyDrivingLimitHours
}

enum class RouteChoice { TOLL, ARTERIAL }

data class RouteQuote(
    val distanceKm: Int,
    val estimatedHours: Double,
    val fuelCostIdr: Long,
    val tollCostIdr: Long
)

fun quoteRoute(distanceKm: Int, route: RouteChoice, fuelPricePerLiterIdr: Long, litersPerKm: Double): RouteQuote {
    require(distanceKm > 0 && fuelPricePerLiterIdr >= 0L && litersPerKm > 0.0)
    val speedKmPerHour = if (route == RouteChoice.TOLL) 65.0 else 35.0
    val tollPerKm = if (route == RouteChoice.TOLL) 1_100L else 0L
    val fuel = (distanceKm * litersPerKm * fuelPricePerLiterIdr).toLong()
    return RouteQuote(
        distanceKm = distanceKm,
        estimatedHours = distanceKm / speedKmPerHour,
        fuelCostIdr = fuel,
        tollCostIdr = distanceKm * tollPerKm
    )
}
