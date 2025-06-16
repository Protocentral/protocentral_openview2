import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'sizeConfig.dart';
import 'package:syncfusion_flutter_charts/charts.dart';


/*class buildPlots {
  // Helper to convert FlSpot list to ChartPoint list
  List<ChartPoint> convertSpotsToChartPoints(List<FlSpot> spots) {
    return spots.map((e) => ChartPoint(e.x, e.y)).toList();
  }

  // Main chart builder method
  Widget buildChart(
      int vertical,
      int horizontal,
      List<FlSpot> source,
      Color plotColor,
      ) {
    return Container(
      height: SizeConfig.blockSizeVertical * vertical,
      width: SizeConfig.blockSizeHorizontal * horizontal,
      child: SfCartesianChart(
        plotAreaBorderWidth: 0,
        primaryXAxis: NumericAxis(isVisible: false, majorGridLines: const MajorGridLines(width: 0)),
        primaryYAxis: NumericAxis(isVisible: false, majorGridLines: const MajorGridLines(width: 0)),
        borderWidth: 0,
        series: <CartesianSeries>[
          LineSeries<ChartPoint, double>(
            dataSource: convertSpotsToChartPoints(source),
            xValueMapper: (ChartPoint pt, _) => pt.x,
            yValueMapper: (ChartPoint pt, _) => pt.y,
            color: plotColor,
            width: 3,
            isVisibleInLegend: false,
            markerSettings: const MarkerSettings(isVisible: false),
            animationDuration: 0, // <-- Disable animation
            // You can set splineType to SplineType.natural for curves, or just use LineSeries for straight lines
            // If you want curves, use SplineSeries instead
          )
        ],
        tooltipBehavior: TooltipBehavior(enable: false),
        // No legend, grid or axis titles
      ),
    );
  }
}*/


class buildPlots {
  LineChartBarData currentLine(List<FlSpot> points, Color plotcolor) {
    return LineChartBarData(
      spots: points,
      dotData: FlDotData(
        show: false,
      ),
      gradient: LinearGradient(
        colors: [plotcolor, plotcolor],
        //stops: const [0.1, 1.0],
      ),
      barWidth: 3,
      isCurved: false,
    );
  }

  buildChart(int vertical, int horizontal, List<FlSpot> source, Color plotColor) {
    return Container(
      height: SizeConfig.blockSizeVertical * vertical,
      width: SizeConfig.blockSizeHorizontal * horizontal,
      child: LineChart(
        LineChartData(
          lineTouchData: LineTouchData(enabled: false),
          clipData: FlClipData.all(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            drawHorizontalLine: false,
          ),
          borderData: FlBorderData(
            show: false,
            //border: Border.all(color: const Color(0xff37434d)),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [
            currentLine(source, plotColor),
          ],
        ),
        //swapAnimationDuration: Duration.zero,
        duration: Duration.zero,
      ),
    );
  }

}

class ChartPoint {
  final double x;
  final double y;
  ChartPoint(this.x, this.y);
}

