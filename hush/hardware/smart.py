import logging

logger = logging.getLogger(__name__)
from typing import Any, Dict, List, Optional
import re
import numpy as np
from . import Device

class Smart(Device):
    def __init__(self, host: str, drives: Optional[List[str]] = None) -> None:
        super().__init__(host)
        self._drives = drives
        self.get_os_credentials()

    async def get_drive_list(self):
        drive_paths = []
        try:
            result = await self.ssh.shell("fdisk -l")
            drive_paths = re.findall(r"Disk (\/dev\/sd[a-z]+|\/dev\/nvme[0-9]+n[0-9]+)", result.stdout)
        except Exception as e:
            logger.info(f"{self} failed to get drive list:")
            logger.info(f"result = {result}")
            raise e
        return drive_paths

    async def get_drive_temp(self, drive_path, fallback_temp=30):
        try:
            result = await self.ssh.shell(f'smartctl -a {drive_path}')
            output = "\n".join(result.stdout_lines)

            # SATA: Attribute 194 / 190
            sata_match = re.search(
                r"\b(194|190)\s+\w+\s+\S+\s+\d+\s+\d+\s+\d+\s+\S+\s+\S+\s+-\s+(\d+)", output
            )
            if sata_match:
                return float(sata_match.group(2))

            # NVMe: Zeile mit 'Temperature: 49 Celsius'
            nvme_match = re.search(r"Temperature:\s+(\d+)\s+Celsius", output)
            if nvme_match:
                return float(nvme_match.group(1))

            # Alternative S.M.A.R.T.-Formate (seltener)
            for line in result.stdout_lines:
                temp = re.search(r"Current\s+Temperature:\s+(\d+)\s+Celsius", line)
                if temp:
                    return float(temp.group(1))

            # Keine Temperatur gefunden
            logger.info(f"{self.hostname} konnte keine Temperatur ermitteln ({drive_path}) – Fallback {fallback_temp}°C")
            return fallback_temp

        except Exception as e:
            logger.info(f"{self.hostname} Fehler bei Temperaturmessung {drive_path} – Fallback {fallback_temp}°C")
            logger.info(f"Exception: {e}")
            return fallback_temp

    async def get_temp(self):
        try:
            drive_temps = list()
            if self._drives is None or self._drives == []:
                self._drives = await self.get_drive_list()
            for drive_path in self._drives:
                temp = await self.get_drive_temp(drive_path=drive_path)
                if temp is not None:
                    drive_temps.append(float(temp))
            self._temp = int(np.max(drive_temps))
            return self._temp
        except Exception as e:
            logger.info(f"drive_paths = {self._drives}")
            logger.info(f"drive_temps = {drive_temps}")
            raise e
