<?php
/**
 * OpenEyes.
 *
 * (C) OpenEyes Foundation, 2016
 * This file is part of OpenEyes.
 * OpenEyes is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
 * OpenEyes is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
 * You should have received a copy of the GNU General Public License along with OpenEyes in a file titled COPYING. If not, see <http://www.gnu.org/licenses/>.
 *
 * @link http://www.openeyes.org.uk
 *
 * @author OpenEyes <info@openeyes.org.uk>
 * @copyright Copyright (c) 2016, OpenEyes Foundation
 * @license http://www.gnu.org/licenses/gpl-3.0.html The GNU General Public License V3.0
 */
?>

<?php $this->beginContent('//patient/event_container'); ?>
<?php
$this->event_actions[] = EventAction::button('Send', 'save', array('level' => 'save'), array('form' => 'messaging-create'));
?>

<?php $form = $this->beginWidget('BaseEventTypeCActiveForm', array(
    'id' => 'messaging-create',
    'enableAjaxValidation' => false,
    'layoutColumns' => array(
        'label' => 4,
        'field' => 8,
    ),
));
?>

<?php

if (!empty($errors)) {
    ;
}  ?>
<script type='text/javascript'>
    $(document).ready( function(){
        window.formHasChanged = true;
    });
</script>

<?php $this->displayErrors($errors)?>

<?php $this->renderPartial('//patient/event_elements', array('form' => $form));?>
<?php $this->displayErrors($errors, true)?>

<?php $this->endWidget()?>
<?php $this->endContent();?>