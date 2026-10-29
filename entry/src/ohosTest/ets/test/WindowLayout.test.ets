import { describe, it, expect } from '@ohos/hypium';
import { SizeClass, WindowLayout } from '../../../main/ets/common/window/WindowLayout';

export default function windowLayoutTest() {
  describe('WindowLayoutBreakpoints', () => {
    it('sizeClassOf_shouldSwitchAtBreakpoints', 0, () => {
      expect(WindowLayout.sizeClassOf(320)).assertEqual(SizeClass.SM);
      expect(WindowLayout.sizeClassOf(599.9)).assertEqual(SizeClass.SM);
      expect(WindowLayout.sizeClassOf(600)).assertEqual(SizeClass.MD);
      expect(WindowLayout.sizeClassOf(839.9)).assertEqual(SizeClass.MD);
      expect(WindowLayout.sizeClassOf(840)).assertEqual(SizeClass.LG);
      expect(WindowLayout.sizeClassOf(1199.9)).assertEqual(SizeClass.LG);
      expect(WindowLayout.sizeClassOf(1200)).assertEqual(SizeClass.XL);
      expect(WindowLayout.sizeClassOf(1600)).assertEqual(SizeClass.XL);
    });

    it('isWide_shouldBeTrueFrom840vp', 0, () => {
      expect(WindowLayout.isWide(839)).assertFalse();
      expect(WindowLayout.isWide(840)).assertTrue();
      expect(WindowLayout.isWide(1600)).assertTrue();
    });

    it('gridColumns_shouldMatchSpecMapping', 0, () => {
      expect(WindowLayout.gridColumns(400)).assertEqual(2);
      expect(WindowLayout.gridColumns(700)).assertEqual(3);
      expect(WindowLayout.gridColumns(900)).assertEqual(4);
      expect(WindowLayout.gridColumns(1199)).assertEqual(4);
      expect(WindowLayout.gridColumns(1300)).assertEqual(6);
      expect(WindowLayout.gridColumns(1600)).assertEqual(6);
    });

    it('isLandscapeVideo_shouldOnlyDependOnAspect', 0, () => {
      expect(WindowLayout.isLandscapeVideo(0.5625)).assertFalse();
      expect(WindowLayout.isLandscapeVideo(1)).assertFalse();
      expect(WindowLayout.isLandscapeVideo(1.2)).assertFalse();
      expect(WindowLayout.isLandscapeVideo(1.778)).assertTrue();
    });

    it('gridMaxWidth_shouldCapSingleCardWidth', 0, () => {
      const sixColumns = WindowLayout.gridMaxWidth(6);
      const cardWidth = (sixColumns - 5 * WindowLayout.CARD_GAP) / 6;
      expect(cardWidth <= WindowLayout.CARD_MAX_WIDTH).assertTrue();
      expect(WindowLayout.gridMaxWidth(2) < sixColumns).assertTrue();
    });
  });
}
