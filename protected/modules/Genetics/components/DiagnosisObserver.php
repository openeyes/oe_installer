<?php
/**
 * OpenEyes.
 *
 * (C) Moorfields Eye Hospital NHS Foundation Trust, 2008-2011
 * (C) OpenEyes Foundation, 2011-2013
 * This file is part of OpenEyes.
 * OpenEyes is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
 * OpenEyes is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
 * You should have received a copy of the GNU General Public License along with OpenEyes in a file titled COPYING. If not, see <http://www.gnu.org/licenses/>.
 *
 * @link http://www.openeyes.org.uk
 *
 * @author OpenEyes <info@openeyes.org.uk>
 * @copyright Copyright (c) 2008-2011, Moorfields Eye Hospital NHS Foundation Trust
 * @copyright Copyright (c) 2011-2013, OpenEyes Foundation
 * @license http://www.gnu.org/licenses/gpl-3.0.html The GNU General Public License V3.0
 */

/**
 * Class DiagnosisObserver.
 */
class DiagnosisObserver
{
    /**
     * @param array $params
     * @throws Exception
     */
    public function patientAddDiagnosis(array $params)
    {
        if (!(array_key_exists('diagnosis', $params) && is_a($params['diagnosis'], 'SecondaryDiagnosis'))) {
            throw new Exception('Parameters Incorrect');
        }
        $secondary_diagnosis = $params['diagnosis'];
        self::updatePedigreeDiagnosis($secondary_diagnosis->patient);
    }

    /**
     * @param array $params
     * @throws Exception
     */
    public function patientRemoveDiagnosis(array $params)
    {
        if (!(array_key_exists('patient', $params) && is_a($params['patient'], 'patient'))) {
            throw new Exception('Parameters Incorrect');
        }
        $patient = $params['patient'];
        self::updatePedigreeDiagnosis($patient->id);
    }

    /**
     * @param $patient
     * @throws Exception
     */
    private function updatePedigreeDiagnosis($patient)
    {
        try {
            PedigreeDiagnosisAlgorithm::updatePedigreeDiagnosisByPatient($patient->id);
        } catch (Exception $exp) {
            if ($exp->getMessage() !== 'Patient has no pedigree') {
                throw $exp;
            }
        }
    }
}
