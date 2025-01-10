//
// This source file is part of the Stanford Spezi Template Application open-source project
//
// SPDX-FileCopyrightText: 2023 Stanford University
//
// SPDX-License-Identifier: MIT
//
// Nikhil Krishnaswamy

import SpeziAccount
import SpeziHealthKit
import SpeziViews
import SwiftUI
import Charts
import HealthKit

struct DashboardView: View {
    private let healthStore = HKHealthStore()
    @State private var stepData: [(Date, Double)] = []
    @State private var goal: Double = 10000 // Example goal
    @State private var progress: Double = 0
    @State private var todaySteps: Double = 0
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    todayStepsCard
                    progressCard
                    monthlyOverviewChart
                    weeklyComparisonChart
                    dailyStepDistributionChart
                    cumulativeStepsChart
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .task {
                await loadStepData()
            }
        }
    }
    
    private var todayStepsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "figure.walk")
                    .foregroundColor(.blue)
                Text("Today")
                    .font(.headline)
                Spacer()
                Text("\(Int(todaySteps)) steps")
                    .font(.title)
                    .bold()
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1)))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Progress to Goal")
                .font(.headline)
            
            ProgressView(value: progress, total: goal)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
            
            Text("\(Int(progress)) / \(Int(goal)) steps")
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1)))
    }
    
    private var monthlyOverviewChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Monthly Overview")
                .font(.headline)
            
            if !stepData.isEmpty {
                let monthlyAverage = stepData.map { $0.1 }.reduce(0, +) / Double(stepData.count)
                Text("\(Int(monthlyAverage)) steps/day")
                    .font(.subheadline)
                
                Chart {
                    ForEach(Array(stepData.enumerated()), id: \.offset) { index, data in
                        LineMark(
                            x: .value("Date", data.0, unit: .day),
                            y: .value("Steps", data.1)
                        )
                        .foregroundStyle(.blue)
                        
                        AreaMark(
                            x: .value("Date", data.0, unit: .day),
                            y: .value("Steps", data.1)
                        )
                        .foregroundStyle(.blue.opacity(0.3))
                    }
                    
                    RuleMark(y: .value("Average", monthlyAverage))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))
                        .foregroundStyle(.red)
                }
                .frame(height: 200)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1)))
    }
    
    private var weeklyComparisonChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weekly Comparison")
                .font(.headline)
            
            let thisWeekSteps = stepData.suffix(7).map { $0.1 }.reduce(0, +)
            let lastWeekSteps = stepData.dropLast(7).suffix(7).map { $0.1 }.reduce(0, +)
            
            Chart {
                BarMark(
                    x: .value("Week", "Last Week"),
                    y: .value("Steps", lastWeekSteps)
                )
                .foregroundStyle(.blue)
                
                BarMark(
                    x: .value("Week", "This Week"),
                    y: .value("Steps", thisWeekSteps)
                )
                .foregroundStyle(.purple)
            }
            .frame(height: 200)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1)))
    }
    
    private var dailyStepDistributionChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Daily Step Distribution")
                .font(.headline)
            
            if !stepData.isEmpty {
                Chart {
                    ForEach(Array(stepData.enumerated()), id: \.offset) { index, data in
                        PointMark(
                            x: .value("Date", data.0, unit: .day),
                            y: .value("Steps", data.1)
                        )
                        .foregroundStyle(.purple)
                    }
                }
                .frame(height: 200)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1)))
    }
    
    private var cumulativeStepsChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cumulative Steps")
                .font(.headline)
            
            if !stepData.isEmpty {
                let cumulativeData = stepData.reduce(into: [(Date, Double)]()) { result, data in
                    let lastValue = result.last?.1 ?? 0
                    result.append((data.0, lastValue + data.1))
                }
                
                Chart {
                    ForEach(Array(cumulativeData.enumerated()), id: \.offset) { index, data in
                        LineMark(
                            x: .value("Date", data.0, unit: .day),
                            y: .value("Cumulative Steps", data.1)
                        )
                        .foregroundStyle(.blue)
                    }
                }
                .frame(height: 200)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1)))
    }
    
    private func loadStepData() async {
        await fetchMonthlySteps()
        await fetchTodaySteps()
    }
    
    private func fetchMonthlySteps() async {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -30, to: endDate) ?? endDate
        
        let stepType = HKQuantityType(.stepCount)
        let interval = DateComponents(day: 1)
        let query = HKStatisticsCollectionQuery(
            quantityType: stepType,
            quantitySamplePredicate: nil,
            options: .cumulativeSum,
            anchorDate: startDate,
            intervalComponents: interval
        )
        
        query.initialResultsHandler = { _, results, error in
            if let error = error {
                print("Error fetching health data: \(error)")
                return
            }
            
            guard let results = results else { return }
            
            var newStepData: [(Date, Double)] = []
            results.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                if let sum = statistics.sumQuantity() {
                    let steps = sum.doubleValue(for: HKUnit.count())
                    newStepData.append((statistics.startDate, steps))
                }
            }
            
            DispatchQueue.main.async {
                stepData = newStepData
            }
        }
        
        healthStore.execute(query)
    }
    
    private func fetchTodaySteps() async {
        let calendar = Calendar.current
        let endDate = Date()
        let stepType = HKQuantityType(.stepCount)
        let todayStart = calendar.startOfDay(for: endDate)
        let todayPredicate = HKQuery.predicateForSamples(withStart: todayStart, end: endDate, options: .strictStartDate)
        
        let todayQuery = HKStatisticsQuery(
            quantityType: stepType,
            quantitySamplePredicate: todayPredicate,
            options: .cumulativeSum
        ) { _, result, error in
            if let error = error {
                print("Error fetching today's steps: \(error)")
                return
            }
            
            if let sum = result?.sumQuantity() {
                let steps = sum.doubleValue(for: HKUnit.count())
                DispatchQueue.main.async {
                    todaySteps = steps
                    progress = steps
                    print("Today's Steps: \(todaySteps)")
                }
            }
        }
        
        healthStore.execute(todayQuery)
    }
}

#if DEBUG
#Preview {
    DashboardView()
        .previewWith(standard: TemplateApplicationStandard()) {
            HealthKit()
        }
}
#endif
