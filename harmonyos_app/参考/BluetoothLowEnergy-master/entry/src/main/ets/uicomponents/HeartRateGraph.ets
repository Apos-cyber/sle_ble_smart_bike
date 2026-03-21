/*
 * Copyright (c) 2025 Huawei Device Co., Ltd.
 * Licensed under the Apache License,Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
import { Logger } from '../utils/Logger';
import CommonUtils from '../utils/CommonUtils';
import { COLOR_LINE, COORDINATE_SIZE, MAX_HEART_RATE, SIZE, TIME_PLACEHOLDER } from '../contants/CommonConstants';

/**
 * Heart rate line chart component to render real-time data.
 */
@ComponentV2
export default struct HeartRateGraph {
  // Heart rate value provided by parent; triggers onHeartRate watcher.
  @Param @Require heartRate: number = 0;
  // View width provided by parent; triggers layout recalculation.
  @Param @Require viewWidth: number;
  // View height provided by parent; triggers layout recalculation.
  @Param @Require viewHeight: number;
  // Whether the graph is active and should accept new samples.
  @Param @Require isActive: boolean = true;
  // Sliding window of heart rate samples.
  @Local heartRateArr: Array<number> = [];
  // Sliding window of timestamps aligned with heartRateArr.
  @Local timeArr: Array<string> = [];
  // Canvas rendering context settings.
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  // 2D canvas context.
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  // Cached X coordinate of the end of horizontal guide lines.
  private mCoordinateLineEndX: number = 0;
  // Cached uniform horizontal offset between sample points.
  private mOffset: number = 0;
  // Cached ratio used to convert bpm value to pixel height.
  private mHeightRatio: number = 0;
  // Y-axis scale ticks for bpm labels.
  private mHeartRateCoordinateArr: Array<number> = [];
  // Cached UI metrics derived from UIContext.
  private lineWidth: number = 1.846;
  private widthChangePoint: number = 276.923;
  private xCoordinateTextHeight: number = 9.231;
  private startX: number = 12.308;
  private paddingVertical: number = 12.308;
  private paddingHorizontal: number = 12.308;

  /**
   * Lifecycle: initialize layout and series before first draw.
   */
  aboutToAppear(): void {
    this.calculateLayoutConfig();
    this.initializeSeries();
  }

  /**
   * Watcher: called when heartRate changes; pushes new value and redraws.
   */
  @Monitor('heartRate')
  onHeartRate() {
    if (!this.isActive) {
      // Do not update when connection is inactive.
      return;
    }
    Logger.info('[HeartRateGraph] onHeartRate trigger', JSON.stringify(this.heartRate));
    this.heartRateArr.push(this.heartRate);
    if (this.heartRateArr.length > SIZE) {
      this.heartRateArr.shift();
    }

    this.timeArr.push(CommonUtils.dateFormat(new Date(), 'HH:mm:ss'));
    if (this.timeArr.length > SIZE) {
      this.timeArr.shift();
    }
    this.draw();
  }

  /**
   * Watcher: invoked when view size changes; recalculates layout and redraws.
   */
  @Monitor('viewWidth','viewHeight')
  onViewSizeChange() {
    this.calculateLayoutConfig();
    this.draw();
  }

  /**
   * Watcher: invoked when active state changes; resets data and redraws.
   */
  @Monitor('isActive')
  onActiveChange() {
    this.resetSeries();
    this.draw();
  }

  /**
   * Compute internal layout parameters based on current width/height.
   */
  calculateLayoutConfig() {
    this.refreshMetrics();
    this.mCoordinateLineEndX = this.viewWidth - this.paddingHorizontal;
    this.mOffset = (this.viewWidth - this.startX - this.paddingHorizontal * 2) / (SIZE - 1);
    this.mHeightRatio =
      (this.viewHeight - this.paddingVertical * 2 - this.xCoordinateTextHeight * 2) / MAX_HEART_RATE;
    let heartRateCoordinate: number = MAX_HEART_RATE / (COORDINATE_SIZE - 1);
    this.mHeartRateCoordinateArr =
      [0, heartRateCoordinate, heartRateCoordinate * 2, heartRateCoordinate * 3, heartRateCoordinate * 4];
  }

  /**
   * Redraw the entire canvas.
   */
  draw() {
    this.context.clearRect(0, 0, this.viewWidth, this.viewHeight);
    this.drawCoordinate();
    this.drawHeartRateLine();
  }

  /**
   * Draw axes, grid lines and auxiliary labels.
   */
  drawCoordinate() {
    this.context.lineWidth = this.lineWidth / 3;
    this.context.font = '16px sans-serif';

    // Draw Y-axis bpm labels.
    let path: Path2D = new Path2D();
    this.context.fillStyle = '#999999';
    for (let i = 0; i < COORDINATE_SIZE; i++) {
      let text = `${this.mHeartRateCoordinateArr[i]}bpm`;
      let offsetY =
        (this.viewHeight - this.paddingVertical * 2 - this.xCoordinateTextHeight * 2) / (COORDINATE_SIZE - 1);
      let x = 0;
      let y = this.viewHeight - this.paddingVertical - this.xCoordinateTextHeight * 2 - offsetY * i +
        this.context.measureText(text)?.height / 4;
      path.moveTo(x, y);
      this.context.fillText(text, x, y);
      this.context.stroke(path);
    }

    // Draw horizontal grid lines.
    this.context.strokeStyle = '#1A000000';
    for (let i = 0; i < COORDINATE_SIZE; i++) {
      let offsetY =
        (this.viewHeight - this.paddingVertical * 2 - this.xCoordinateTextHeight * 2) / (COORDINATE_SIZE - 1);
      let x = this.startX + this.paddingHorizontal;
      let y = this.viewHeight - this.paddingVertical - this.xCoordinateTextHeight * 2 - offsetY * i;
      let path1: Path2D = new Path2D();
      path1.moveTo(x, y);
      path1.lineTo(this.mCoordinateLineEndX, y);
      this.context.stroke(path1);
    }

    // Draw X-axis timestamps.
    this.context.fillStyle = '#999999';
    let path2: Path2D = new Path2D();
    for (let i = 0; i < SIZE; i++) {
      if (this.viewWidth <= this.widthChangePoint && i % 2 === 0) {
        continue;
      }
      let text = this.timeArr[i];
      let x = this.startX + this.mOffset * i + this.paddingHorizontal -
        this.context.measureText(text)?.width / 2;
      let y = this.viewHeight - this.paddingVertical - this.xCoordinateTextHeight;
      path2.moveTo(x, y);
      this.context.fillText(text, x, y);
      this.context.stroke(path2);
    }

    // Draw the latest sample values along the bottom row (bpm text under each tick).
    this.context.fillStyle = '#333333';
    let path3: Path2D = new Path2D();
    for (let i = 0; i < SIZE; i++) {
      if (this.viewWidth <= this.widthChangePoint && i % 2 === 0) {
        continue;
      }
      let text = `${this.heartRateArr[i]}bpm`;
      let x = this.startX + this.mOffset * i + this.paddingHorizontal -
        this.context.measureText(text)?.width / 2;
      let y = this.viewHeight - this.paddingVertical;
      path3.moveTo(x, y);
      this.context.fillText(text, x, y);
      this.context.stroke(path3);
    }
  }

  /**
   * Draw the heart rate polyline with a vertical fill gradient.
   */
  drawHeartRateLine() {
    this.context.lineWidth = this.lineWidth;
    this.context.strokeStyle = COLOR_LINE;

    let path: Path2D = new Path2D();
    for (let i = 0; i < SIZE; i++) {
      let x = this.startX + this.mOffset * i + this.paddingHorizontal;
      let y = this.viewHeight - this.paddingVertical - this.xCoordinateTextHeight * 2 -
        this.heartRateArr[i] * this.mHeightRatio;
      if (i === 0) {
        // Start by drawing from bottom up to the first data point.
        path.moveTo(x, this.viewHeight - this.paddingVertical - this.xCoordinateTextHeight * 2);
        path.lineTo(x, y);
      } else {
        path.lineTo(x, y);
      }

      // Close the shape back to the bottom at the last point to enable fill.
      if (i === SIZE - 1) {
        path.lineTo(x, this.viewHeight - this.paddingVertical - this.xCoordinateTextHeight * 2);
      }
    }
    let gradient = this.context.createLinearGradient(0, this.paddingVertical, 0,
      this.viewHeight - this.paddingVertical - this.xCoordinateTextHeight * 2);
    gradient.addColorStop(0.0, '#660A59F7');
    gradient.addColorStop(1.0, '#660A59F7');
    this.context.fillStyle = gradient;
    this.context.fill(path);
    this.context.stroke(path);

    // Clear the vertical edges to keep borders crisp.
    this.context.clearRect(this.startX + this.paddingHorizontal - this.lineWidth / 2, 0, this.lineWidth,
      this.viewHeight - this.paddingVertical - this.xCoordinateTextHeight * 2 + this.lineWidth / 2);
    this.context.clearRect(this.viewWidth - this.paddingHorizontal - this.lineWidth / 2, 0, this.lineWidth,
      this.viewHeight - this.paddingVertical - this.xCoordinateTextHeight * 2 + this.lineWidth / 2);
  }

  build() {
    Canvas(this.context)
      .width(this.viewWidth)
      .height(this.viewHeight)
      .onReady(() => {
        this.draw();
      })
  }

  private refreshMetrics(): void {
    const uiContext = this.getUIContext() ?? CommonUtils.getUIContext();
    if (uiContext) {
      this.lineWidth = uiContext.px2vp(6);
      this.widthChangePoint = uiContext.px2vp(900);
      this.xCoordinateTextHeight = uiContext.px2vp(30);
      this.startX = uiContext.px2vp(40);
      this.paddingVertical = uiContext.px2vp(40);
      this.paddingHorizontal = uiContext.px2vp(40);
    } else {
      this.lineWidth = 1.846;
      this.widthChangePoint = 276.923;
      this.xCoordinateTextHeight = 9.231;
      this.startX = 12.308;
      this.paddingVertical = 12.308;
      this.paddingHorizontal = 12.308;
    }
  }

  /**
   * Initialize or reset series arrays to default placeholders.
   */
  private initializeSeries(): void {
    this.heartRateArr = new Array<number>(SIZE).fill(0);
    this.timeArr = new Array<string>(SIZE).fill(TIME_PLACEHOLDER);
  }

  /**
   * Reset heart rate and timestamp series to initial state.
   */
  private resetSeries(): void {
    this.initializeSeries();
  }
}